require 'forwardable'
require 'thread'
require 'sexp_path'

class SexpBuilder
  autoload :Context,      'sexp_builder/context'
  autoload :QueryBuilder, 'sexp_builder/query_builder'
  attr_reader :context, :scope
  
  def initialize
    @context = self.class.current_context
    @main = @context.main_context
    @scope = []
    @rewriters = {}
    @query_builders = {}
  end
  
  def process(sexp, options = {})
    @scope.unshift(sexp.sexp_type)

    rewriters.each do |query, method|
      if data = query.satisfy?(sexp, QueryBuilder::Data.new)
        return method.call(SexpPath::SexpResult.new(sexp, data))
      end
    end
    
    # If none of the rewriters matched, process the children:
    sexp.inject(Sexp.new) do |memo, exp|
      memo << if exp.is_a?(Sexp)
        process(exp)
      else
        exp
      end
    end
  ensure
    @scope.shift     
  end
  
  def process_main(sexp, options = {})
    prev, @context = @context, @main
    process(sexp, options)
  ensure
    @context = prev
  end
  
  def rewriters(context = @context)
    @rewriters[context] ||= begin
      context.rewriters.map do |rule|
        [query_builder(context).send(rule), method("rewrite_#{rule}")]
      end
    end
  end
  
  def query_builder(context = @context)
    @query_builders[context] ||= begin
      QueryBuilder.make(context, self)
    end
  end
  
  class << self
    extend Forwardable
    attr_accessor :current_context
    def_delegators :@current_context, :context, :matcher, :rule, :rewrite
    
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
      name.scan(/.[^A-Z]+/).map { |part| part.downcase }.join("_")
    end
    
    def tmpid
      @tmpid ||= 0
      @tmpid += 1
    end
  end
end