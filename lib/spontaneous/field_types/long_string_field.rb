# encoding: UTF-8

module Spontaneous::FieldTypes
  class LongStringField < Field
    include Spontaneous::Plugins::Field::EditorClass

    def generate_html(value)
      escape_html(value).gsub(/[\r\n]+/, "<br />")
    end

    self.register
  end # LongStringField
end
