# frozen_string_literal: true

module GrapeSwagger
  module Entity
    class AttributeParser
      attr_reader :endpoint

      # The list of that doesn't handled by `GrapeSwagger::DocMethods::DataType.primitive?` method
      ADDITIONAL_PRIMITIVE_TYPES = %w[string array].freeze

      def initialize(endpoint)
        @endpoint = endpoint
      end

      def call(entity_options)
        param = if (entity_model = model_from(entity_options))
                  name = GrapeSwagger::Entity::Helper.model_name(entity_model, endpoint)
                  entity_model_type(name, entity_options)
                else
                  data_type_from(entity_options)
                end

        documentation = entity_options[:documentation]
        return param if documentation.nil?

        add_array_documentation(param, documentation) if documentation[:is_array]

        add_attribute_sample(param, documentation, :default)
        add_attribute_sample(param, documentation, :example)

        add_attribute_documentation(param, documentation)

        add_extension_documentation(param, documentation)
        add_discriminator_extension(param, documentation)
        param
      end

      private

      def model_from(entity_options)
        model = entity_options[:using] if entity_options[:using].present?

        model ||= entity_options[:documentation][:type] if could_it_be_a_model?(entity_options[:documentation])

        model
      end

      def could_it_be_a_model?(value)
        return false if value.nil?

        direct_model_type?(value[:type]) || ambiguous_model_type?(value[:type])
      end

      def direct_model_type?(type)
        type.to_s.include?('Entity') || type.to_s.include?('Entities')
      end

      def ambiguous_model_type?(type)
        type&.is_a?(Class) && !primitive_type?(type)
      end

      def primitive_type?(type)
        data_type = GrapeSwagger::DocMethods::DataType.call(type)
        GrapeSwagger::DocMethods::DataType.primitive?(data_type) ||
          ADDITIONAL_PRIMITIVE_TYPES.include?(data_type)
      end

      def data_type_from(entity_options)
        documentation = entity_options[:documentation] || {}
        documented_type = entity_options[:type] || documentation[:type]

        data_type = GrapeSwagger::DocMethods::DataType.call(documented_type)

        documented_data_type = document_data_type(documentation, data_type)

        if documentation[:is_array]
          {
            type: :array,
            items: documented_data_type
          }
        else
          documented_data_type
        end
      end

      def document_data_type(documentation, data_type)
        type = if GrapeSwagger::DocMethods::DataType.primitive?(data_type)
                 data = GrapeSwagger::DocMethods::DataType.mapping(data_type)
                 { type: data.first, format: data.last }
               else
                 { type: data_type }
               end

        type[:format] = documentation[:format] if documentation.key?(:format)

        values = documentation[:values]
        values = values.call if values.is_a?(Proc)
        type[:enum] = values if values.is_a?(Array)

        type
      end

      def entity_model_type(name, entity_options)
        if entity_options[:documentation] && entity_options[:documentation][:is_array]
          {
            'type' => 'array',
            'items' => {
              '$ref' => "#/definitions/#{name}"
            }
          }
        else
          {
            '$ref' => "#/definitions/#{name}"
          }
        end
      end

      def add_attribute_sample(attribute, hash, key)
        value = hash[key]
        return if value.nil?

        attribute[key] = value.is_a?(Proc) ? value.call : value
      end

      def add_attribute_documentation(param, documentation)
        param[:minimum] = documentation[:minimum] if documentation.key?(:minimum)
        param[:maximum] = documentation[:maximum] if documentation.key?(:maximum)

        values = documentation[:values]
        if values&.is_a?(Range)
          param[:minimum] = values.begin if values.begin.is_a?(Numeric)
          param[:maximum] = values.end if values.end.is_a?(Numeric)
        end

        param[:minLength] = documentation[:min_length] if documentation.key?(:min_length)
        param[:maxLength] = documentation[:max_length] if documentation.key?(:max_length)
      end

      def add_array_documentation(param, documentation)
        param[:minItems] = documentation[:min_items] if documentation.key?(:min_items)
        param[:maxItems] = documentation[:max_items] if documentation.key?(:max_items)
        param[:uniqueItems] = documentation[:unique_items] if documentation.key?(:unique_items)
      end

      def add_extension_documentation(param, documentation)
        GrapeSwagger::DocMethods::Extensions.add_extensions_to_root(documentation, param)
      end

      def add_discriminator_extension(param, documentation)
        param[:documentation] = { is_discriminator: true } if documentation.key?(:is_discriminator)
      end
    end
  end
end
