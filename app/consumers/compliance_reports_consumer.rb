# frozen_string_literal: true

# Raise an error if entitlement is not available
class EntitlementError < StandardError; end

# Receives messages from the Kafka topic, converts them into jobs
# for processing
class ComplianceReportsConsumer < ApplicationConsumer
  subscribes_to Settings.platform_kafka_topic

  def process(message)
    @msg_value = JSON.parse(message.value)
    raise EntitlementError unless identity.valid?

    download_file
    enqueue_job
  rescue EntitlementError, SafeDownloader::DownloadError => e
    logger.error "Error parsing report: #{message_id}"\
      " - #{e.message}"
    send_validation('failure')
  end

  def send_validation(validation)
    produce(
      validation_payload(message_id, validation),
      topic: Settings.platform_kafka_validation_topic
    )
  end

  private

  def identity
    IdentityHeader.new(@msg_value['b64_identity'])
  end

  def message_id
    @msg_value.fetch('request_id', @msg_value.dig('payload_id'))
  end

  def download_file
    @report_contents = SafeDownloader.download(@msg_value['url'])
  end

  def enqueue_job
    if validate == 'success'
      logger.info "Received message, enqueueing: #{@msg_value}"
      job = ParseReportJob.perform_async(
        ActiveSupport::Gzip.compress(@report_contents), @msg_value
      )
      logger.info "Message enqueued: #{message_id} as #{job}"
    else
      logger.error "Error parsing report: #{message_id}"
    end
  end

  def validate
    message = validation_message
    send_validation(message)
    message
  end

  def validation_message
    XCCDFReportParser.new(@report_contents, @msg_value)
    'success'
  rescue StandardError => e
    logger.error "Error validating report: #{message_id}"\
      " - #{e.message}"
    'failure'
  end

  def validation_payload(request_id, result)
    {
      'payload_id': request_id,
      'request_id': request_id,
      'service': 'compliance',
      'validation': result
    }.to_json
  end

  def logger
    Rails.logger
  end
end
