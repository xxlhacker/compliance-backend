# frozen_string_literal: true

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end

# rubocop:disable Metrics/MethodLength
def stub_rbac_permissions(*permissions)
  role_permissions = permissions.map do |permission|
    RBACApiClient::Access.new(
      permission: permission,
      resource_definitions: nil
    )
  end
  role = RBACApiClient::AccessPagination.new(data: role_permissions)
  allow(Rbac::API_CLIENT).to receive(:get_principal_access).and_return(role)
end
# rubocop:enable Metrics/MethodLength
