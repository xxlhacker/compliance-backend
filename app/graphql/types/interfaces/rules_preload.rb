# frozen_string_literal: true

module Types
  module Interfaces
    # Class to deal with preloading various attributes for rules, such as
    # rule results, compliant,and references
    module RulesPreload
      include GraphQL::Schema::Interface

      def rules(args = {})
        context[:parent_profile_id] ||= {}
        return all_rules if system_id(args).blank?

        latest_test_result_batch(args).then do |latest_test_result|
          latest_rule_results_batch(latest_test_result).then do |rule_results|
            rules_for_rule_results_batch(rule_results).then do |rules|
              initialize_rules_context(rules.compact, rule_results, args)
              rules.compact
            end
          end
        end
      end

      def latest_rule_results_batch(latest_test_result)
        if latest_test_result.blank?
          return Promise.resolve(::RuleResult.where('1=0'))
        end

        ::CollectionLoader.for(::TestResult, :rule_results)
                          .load(latest_test_result)
      end

      def rules_for_rule_results_batch(rule_results)
        ::RecordLoader.for(::Rule).load_many(rule_results.pluck(:rule_id))
      end

      def all_rules
        ::CollectionLoader.for(::Profile, :rules).load(object).then do |rules|
          rules
        end
      end

      def top_failed_rules(args = {})
        ids = ::RuleResult.latest(args[:policy_id]).failed
                          .joins(:rule).group('rules.ref_id')
                          .select('rules.ref_id', 'COUNT(result) as cnt', '(ARRAY_AGG(rule_id))[1] as rule_id')
        # The rule_id selection is non-deterministic here, but it's not important which specific rule we select
        # with the grouped ref_id under the given policy. This deduplication effort also ensures that the query
        # below is something that ActiveRecord can consume further without model compatibility problems.

        ::Rule.joins("INNER JOIN (#{ids.to_sql}) AS failed ON rules.id = failed.rule_id")
              .order(::Rule::SORTED_SEVERITIES => :desc, 'failed.cnt' => :desc)
              .select('rules.*', 'failed.cnt AS failed_count').limit(10)
      end

      def initialize_rules_context(rules, rule_results, args = {})
        rules.each do |rule|
          context[:parent_profile_id][rule.id] = object.id
        end

        initialize_rule_references_context(rule_results) if args[:lookahead].selects?(:references)

        return unless args[:lookahead].selects?(:compliant)

        context[:rule_results] ||= {}
        initialize_rule_results_context(rule_results)
      end

      def initialize_rule_references_context(rule_results)
        rule_ids = rule_results.pluck(:rule_id)

        RuleReferencesContainer.where(rule_id: rule_ids).find_each do |reference|
          context[:"rule_references_#{reference.rule_id}"] = reference.rule_references
        end
      end

      def initialize_rule_results_context(rule_results)
        rule_results.each do |rule_result|
          context[:rule_results][rule_result.rule_id] ||= {}
          context[:rule_results][rule_result.rule_id][object.id] =
            rule_result.result
        end
      end
    end
  end
end
