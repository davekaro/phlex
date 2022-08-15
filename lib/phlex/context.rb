# frozen_string_literal: true

module Phlex
  module Context
    def content(&)
      original_bytesize = @_target.size
      output = yield if block_given?
      unchanged = (original_bytesize == @_target.size)

      text(output) if unchanged && output.is_a?(String)
    end

    def text(content)
      @_target << CGI.escape_html(content)
    end

    def whitespace
      @_target << " "
    end

    def _raw(content)
      @_target << content
    end

    def component(component, *args, **kwargs, &block)
      unless component < Component
        raise ArgumentError, "#{component.name} isn't a Phlex::Component."
      end

      if block_given? && !block.binding.receiver.is_a?(Phlex::Block)
        block = Phlex::Block.new(self, &block)
      end

      component.new(*args, _view_context: @_view_context, _parent: self, **kwargs).call(@_target, &block)
    end

    def template_tag(*args, **kwargs, &)
      _standard_element(*args, _name: "template", **kwargs, &)
    end

    def _standard_element(content = nil, _name: nil, **kwargs, &block)
      raise ArgumentError if content && block_given?

      name = _name ||= __callee__.name

      @_target << Tag::LEFT << name
      _attributes(kwargs) if kwargs.length > 0
      @_target << Tag::RIGHT

      if block_given?
        content(&block)
      else
        text content if content
      end

      @_target << Tag::CLOSE_LEFT << name << Tag::RIGHT
    end

    def _void_element(**kwargs)
      @_target << Tag::LEFT << __callee__.name
      _attributes(kwargs) if kwargs.length > 0
      @_target << Tag::CLOSE_VOID_RIGHT
    end

    def _attributes(attributes)
      if (cached = Phlex::ATTRIBUTE_CACHE[attributes.hash])
        return @_target << cached
      end

      first_render = !self.class.rendered_at_least_once

      buffer = first_render ? buffer = +"" : buffer = @_target

      attributes.each_key do |key|
        if key.match? /[<>&"']/
          raise ArgumentError, <<~MESSAGE
            Unsafe attribute name detected.
            Attributes names shouldn't contain `<`, `>`, `&`, `"` or `'`.
          MESSAGE
        end
      end

      attributes.transform_values! do |value|
        next value if (value == true || value == false)
        CGI.escape_html(value.to_s)
      end

      attributes[:href].sub!(/^\s*(javascript:)+/, "") if attributes[:href]

      attributes.each do |k, v|
        next unless v

        if v == true
          buffer << Tag::SPACE << k.name
        else
          buffer << Tag::SPACE << k.name << Tag::EQUALS_QUOTE << v << Tag::QUOTE
        end
      end

      if first_render
        @_target << Phlex::ATTRIBUTE_CACHE[attributes.hash] = buffer.freeze
      end
    end

    Tag::STANDARD_ELEMENTS.each do |tag_name|
      alias_method tag_name, :_standard_element
    end

    Tag::VOID_ELEMENTS.each do |tag_name|
      alias_method tag_name, :_void_element
    end
  end
end
