# frozen_string_literal: true

module RubyLLM
  class Schema
    module DSL
      module Conditionals
        def conditions
          @conditions ||= []
        end

        def merge_conditions(schema, schema_class)
          return schema unless schema_class.respond_to?(:conditions) && schema_class.conditions.any?

          if schema_class.conditions.length == 1
            schema.merge!(schema_class.conditions.first)
          else
            schema[:allOf] = schema_class.conditions
          end

          schema
        end

        def require_if(property, equals:, &block)
          builder = ConditionalBuilder.new
          builder.instance_eval(&block)

          conditions << {
            if: {
              properties: {property.to_s => {const: equals}},
              required: [property.to_s]
            },
            then: builder.to_then_schema
          }
        end
      end

      class ConditionalBuilder
        def requires(*fields)
          required.concat(fields.map(&:to_s))
        end

        def validates(field, not_value: nil, min_length: nil, pattern: nil)
          constraints = {type: "string"}

          constraints[:not] = {const: not_value} if not_value
          constraints[:minLength] = min_length if min_length
          constraints[:pattern] = pattern if pattern

          validations[field.to_s] = constraints
        end

        def to_then_schema
          schema = {}

          schema[:required] = required if required.any?
          schema[:properties] = validations if validations.any?

          schema
        end

        private

        def required
          @required ||= []
        end

        def validations
          @validations ||= {}
        end
      end
    end
  end
end
