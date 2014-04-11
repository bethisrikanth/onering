module Urlquery
  class Query
    DEFAULT_FIELD_COERCER  = :auto
    DEFAULT_VALUE_OPERATOR = :is
    VALID_OPERATORS_FOR_TYPE={
      :str   => [:contains, :is, :not, :matches, :prefix, :suffix],
      :date  => [:is, :not, :gt, :gte, :lt, :lte, :before, :since],
      :bytes => [:is, :not, :gt, :gte, :lt, :lte],
      :bits  => [:is, :not, :gt, :gte, :lt, :lte],
      :int   => [:is, :not, :gt, :gte, :lt, :lte],
      :float => [:is, :not, :gt, :gte, :lt, :lte],
      :bool  => [:is, :not],
      :nil   => [:is, :not]
    }

    attr_reader :query

    def initialize(base, container=nil)
      @query = base
      @_container = [*container].inject(@query){|s,i|
        s = s[i]
      }
    end

    def option(key, value)
      @query[key] = value
      return self
    end

    def push(clause)
      if @_container.is_a?(Array)
        @_container << clause
      end

      return self
    end

    def <<(clause)
      return push(clause)
    end

    def to_hash()
      return query()
    end

    def self.parse(urlquery, options=nil)
      options ||= {}

      rv = self.new({
        :and => []
      }, :and)

    # inject options
      if options[:query].is_a?(Hash)
        options[:query].each do |k,v|
          rv.option(k.to_sym, v)
        end
      end

      urlquery.split('/').each_slice(2) do |pair|
        field, value = pair
        value    = :exists if value.nil?
        coercer  = DEFAULT_FIELD_COERCER
        operator = nil

      # parse field component
        field.match(/(?:(?<coercer>\w+):)?(?<field>.*)/) do |match|
          coercer = match[:coercer].to_sym unless match[:coercer].nil?
          field   = match[:field]
        end

      # parse value component
        value.match(/(?:(?<operator>\w+):)?(?<value>.*)/) do |match|
          operator = match[:operator] unless match[:operator].nil?
          value    = match[:value]
        end

      # do some pre-processing
        case field

      # any field ending in _at or _on automatically becomes a date (unless explicitly overridden)
        when /_(at|on)$/
          coercer = :date if coercer == DEFAULT_FIELD_COERCER

      # fields 'id' and 'type' are special; they become _id, _type
        when /^(id|type)$/
          field = "_#{field}"
        end

      # preprocess value before typing it
        if options[:normalizer].is_a?(Proc)
          value = options[:normalizer].call(value)
        end

      # convert value to correct data type
        value = value.to_s.convert_to(coercer.to_sym)

      # determine type of automatically-typed values
        if coercer == :auto
          case value.class.name.downcase.to_sym
          when :string
            coercer = :str
          when :fixnum
            coercer = :int
          when :trueclass, :falseclass
            coercer = :bool
          when :date, :time
            coercer = :date
          when :float
            coercer = :float
          when :nilclass
            coercer = :nil
          end
        end


      # =======================================================================
      # Validation
      # =======================================================================

      # the first operator in the valid operators list is the default one (used if one isn't explicitly specified)
      #   if an operator wasn't given, and we have a type mapping for the value's type,
      #   use the first operator in the list
        if operator.nil? and not VALID_OPERATORS_FOR_TYPE[coercer].nil?
          operator = VALID_OPERATORS_FOR_TYPE[coercer].first
        end


        if VALID_OPERATORS_FOR_TYPE.keys.include?(coercer.to_sym)
          if not operator.nil?
            if coercer
              if not VALID_OPERATORS_FOR_TYPE[coercer.to_sym].include?(operator.to_sym)
                raise QueryValidationError.new("cannot use the '#{operator}' operator for type '#{coercer}'")
              end
            end
          else
            raise InvalidOperatorError.new("Could not determine an operator for type '#{coercer}' (value type #{value.class.name})")
          end
        else
          raise QuerySyntaxError.new("Invalid type cast '#{coercer}'")
        end

        op = Urlquery::Operators.const_get("#{operator}_operator".camelize).new()

      # if a multi_field processor is specified, pass the current field name to it and get an array of
      # field names to include in the query
        if options[:multi_field].is_a?(Proc) and (multifields, joiner = options[:multi_field].call(field)).is_a?(Array)
          case multifields.first.length
        # no fields came back, skip this query segment entirely
          when 0
            next

        # only one field came back, don't include the boolean sub-clause
          when 1
            rv << op.to_query(multifields.first.first, value)

          else
            rv << {
              (joiner || :or).to_sym => multifields.collect{|f|
                op.to_query(f, value)
              }
            }
          end
        else
          rv << op.to_query(field, value)
        end
      end

      return rv
    end
  end
end