module AjaxDatatablesRails
  class Filter

    # Construct a filter for reducing records via query.
    #
    # ==== Attributes
    #
    # * +model+ - The ActiveRecord model with the column to be filtered
    # * +column+ - The column name to filter
    # * +value+ - The value for which to create the filter condition
    # * +db_adapter+ - The database adapter symbol
    #
    def initialize(model, column, value, db_adapter)
      @model = model
      @column = column
      @value = value
      @db_adapter = db_adapter
    end

    # Returns an Arel::Nodes::Matches corresponding to the query condition.
    #
    def to_condition
      casted_column = ::Arel::Nodes::NamedFunction.new('CAST', [@model.arel_table[@column.to_sym].as(typecast)])
      casted_column.matches("%#{@value}%")
    end

    # Construct and returns a filter for reducing records via query. If the provided +value+ is blank, then nil is
    # returned instead.
    #
    # ==== Arguments
    #
    # * +column+ - The String column definition in the same format as provided to searchable_columns
    # * +value+ - The value for which to create the filter condition
    # * +db_adapter+ - The database adapter symbol
    #
    def self.from_column(column, value, db_adapter)
      model, column_name = if column[0] == column.downcase[0]
        message = '[DEPRECATED] Using table_name.column_name notation is deprecated. Please refer to: ' +
          'https://github.com/antillas21/ajax-datatables-rails#searchable-and-sortable-columns-syntax'
        ::AjaxDatatablesRails::Base.deprecated(message)

        parsed_model, parsed_column = column.split('.')
        model_name = parsed_model.singularize.titleize.gsub( / /, '' )
        [model_name, parsed_column]
      else
        column.split('.')
      end

      model_class = model.constantize
      if value.blank? then nil
      elsif EnumFilter.column_is_enum?(model_class, column_name)
        EnumFilter.new(model_class, column_name, value, db_adapter)
      else
        Filter.new(model_class, column_name, value, db_adapter)
      end
    end

    protected

    def typecast
      case @db_adapter
        when :oracle then 'VARCHAR2(4000)'
        when :pg then 'VARCHAR'
        when :mysql2 then 'CHAR'
        when :sqlite3 then 'TEXT'
      end
    end
  end

  class EnumFilter < Filter
    # Returns an Arel::Nodes::Matches corresponding to the query condition.
    #
    def to_condition
      # Identify the numeric values to search
      value_map = @model.send(@column.to_s.pluralize)
      db_values = value_map.select { |label, value| label =~ /#{Regexp.escape(@value)}/ }.values

      @model.arel_table[@column.to_sym].in(db_values)
    end

    def self.column_is_enum?(model, column)
      model.defined_enums.include?(column.to_s)
    end
  end
end