# frozen_string_literal: true

require './spec/api/v1/schemas'

module Api
  module V1
    class Openapi
      include Api::V1::Schemas

      def self.doc
        new.doc
      end

      def doc
        {
          openapi: '3.0.3',
          info: info,
          servers: servers,
          paths: {},
          components: {
            schemas: SCHEMAS
          }
        }
      end

      def servers
        [
          {
            url: 'https://{defaultHost}/api/compliance',
            variables: { defaultHost: { default: 'console.redhat.com' } }
          },
          {
            url: 'https://{defaultHost}/api/compliance/v1',
            variables: { defaultHost: { default: 'console.redhat.com' } }
          }
        ]
      end

      def info
        {
          title: 'Cloud Services for RHEL Compliance API V1',
          version: 'v1',
          description: description
        }
      end

      def description
        'This is the API for Cloud Services for RHEL Compliance. '\
          'You can find out more about Red Hat Cloud Services for RHEL at '\
          '[https://console.redhat.com/]'\
          '(https://console.redhat.com/)'
      end
    end
  end
end
