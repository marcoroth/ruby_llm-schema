# frozen_string_literal: true

module RubyLLM
  class Schema
    module JsonOutput
      def to_json_schema
        validate!  # Validate schema before generating JSON

        schema_hash = {
          type: "object",
          properties: self.class.properties,
          required: self.class.required_properties,
          additionalProperties: self.class.additional_properties
        }

        schema_hash[:strict] = self.class.strict unless self.class.strict.nil?

        # Only include $defs if there are definitions
        schema_hash["$defs"] = self.class.definitions unless self.class.definitions.empty?

        if self.class.respond_to?(:conditions) && self.class.conditions.any?
          if self.class.conditions.length == 1
            schema_hash.merge!(self.class.conditions.first)
          else
            schema_hash[:allOf] = self.class.conditions
          end
        end

        {
          name: @name,
          description: @description || self.class.description,
          schema: schema_hash
        }
      end

      def to_json(*_args)
        validate!  # Validate schema before generating JSON string
        JSON.pretty_generate(to_json_schema)
      end
    end
  end
end
