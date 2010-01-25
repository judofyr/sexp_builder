require 'forwardable'
require 'thread'
require 'sexp_path'

class SexpBuilder
  VERSION = "0.1"
  
  autoload :Context,      'sexp_builder/context'
  autoload :QueryBuilder, 'sexp_builder/query_builder'
  attr_reader :context, :scope
  
  # Initializes the builder. If you redefine this in your subclass,
  # it's important to call +super()+.
  def initialize
    @context = self.class.current_context
    @main = @context.main_context
    @scope = []
    @rewriters = {}
    @query_builders = {}
  end
  
  # Process +sexp+ under the current context.
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
  
  # Process +sexp+ under the top context.
  def process_main(sexp, options = {})
    prev, @context = @context, @main
    process(sexp, options)
  ensure
    @context = prev
  end
  
  # Returns an array in the format of:
  #
  #   [<SexpPath::Matcher> rule, <Method> rewriter] 
  def rewriters(context = @context)
    @rewriters[context] ||= context.rewriters.map do |rule|
      [query_builder(context).send(rule), method("rewrite_#{rule}")]
    end
  end
  
  # Returns the query builder for a given context.
  def query_builder(context = @context)
    @query_builders[context] ||= QueryBuilder.make(context, self)
  end
  
  class << self
    extend Forwardable
    # The Context which this builder will process under.
    attr_accessor :current_context
    # Delegates various methods to the current_context.
    def_delegators :@current_context, :context, :matcher, :rule, :rewrite
    
    # Sets up the +current_context+.
    def inherited(mod)
      if self == SexpBuilder
        mod.current_context = Context.new(mod)
      else
        mod.current_context = current_context.context(context_name(mod))
      end
    end
    
    # Turns a module into a context name:
    #
    # * FooBar        => foo_bar
    # * FooBarContext => foo_bar
    # * FooBarBuilder => foo_bar
    def context_name(mod)
      name = mod.name
      name = name.split("::").last
      name.gsub!(/(Context|Builder)$/, '')
      name.scan(/.[^A-Z]+/).map { |part| part.downcase }.join("_")
    end
    
    # Generates a temporary id.
    def tmpid
      @tmpid ||= 0
      @tmpid += 1
    end
  end
end