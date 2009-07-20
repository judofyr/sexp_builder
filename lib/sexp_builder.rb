$:.unshift File.dirname(__FILE__)
$:.unshift File.dirname(__FILE__) + '/../../sexp_path/lib'

require 'forwardable'
require 'thread'
require 'sexp_path'

class SexpBuilder
  autoload :Context,      'sexp_builder/context'
  autoload :QueryBuilder, 'sexp_builder/query_builder'
  attr_reader :context, :scope
  
  def initialize
    @rewriters = {}
    @context = self.class.current_context
    @scope = []
  end
  
  def process(sexp, options = {})
    return sexp unless sexp.is_a?(Sexp)
    
    context = options[:in]
    context = @context.find_context(context) if context.is_a?(Symbol)
    
    if context && context != @context
      old, @context = @context, context
    end
    
    begin
      result = method = nil
      @scope.unshift(sexp.sexp_type)
      
      rewriters(@context).each do |query, meth|
        if data = query.satisfy?(sexp, QueryBuilder::Data.new)
          result = SexpPath::SexpResult.new(sexp, data)
          method = meth
        end
      end
      
      if result
        method.call(result)
      else
        sexp.inject(Sexp.new) do |memo, exp|
          memo << if exp.is_a?(Sexp)
            process(exp)
          else
            exp
          end
        end
      end
    ensure
      @scope.shift
      @context = old if old
    end
  end
  
  private
  
  def rewriters(context)
    @rewriters[context] ||= begin
      query_builder = context.query_builder(self)
      context.rewriters.inject([]) do |memo, (rule, method)|
        memo << [query_builder.send(rule), method(method)]
      end
    end
  end
  
  class << self
    extend Forwardable
    attr_accessor :current_context, :lock
    def_delegators :@current_context, :context, :matcher, :rule, :rewrite, :observe
    
    def inherited(mod)
      if self == SexpBuilder
        mod.current_context = Context.new(mod)
      else
        mod.current_context = current_context.context(context_name(mod))
      end
    end
    
    def context_name(mod)
      name = mod.name
      name = name.split("::").last
      name.gsub!(/(Context|Builder)$/, '')
      name.scan(/.[^A-Z]+/).map { |part| part.downcase }.join("_").to_sym
    end
    
    def tmpid
      @tmpid ||= 0
      @tmpid += 1
    end
  end
end