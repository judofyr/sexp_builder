class SexpBuilder
  class Context
    attr_reader :parent, :builder, :query_scope,
                :contexts, :rewriters
    
    def initialize(builder, parent = nil)
      @builder = builder
      @parent = parent
      
      @contexts  = {}
      @rewriters = []
      
      @query_scope = Module.new do
        include parent.query_scope if parent
      end
    end
    
    def query_builder(instance)
      QueryBuilder.make(self, instance)
    end
    
    def main_context
      if @parent
        @parent.main_context
      else
        self
      end
    end
    
    def find_context(name)
      return main_context if name == :main
      
      if context = @contexts[name]
        return context
      end
      
      @contexts.each do |_, context|
        if context = context.find_context(name)
          return context
        end
      end
      
      nil
    end
    
    def context(name, &blk)
      context = define_context(name)
      context.instance_eval(&blk) if blk
      context
    end
    
    def matcher(name, &blk)
      method_name = define_builder(&blk)

      define_query_scope(name) do
        block do |exp|
          instance.send(method_name, exp)
        end
      end
    end
    
    def rule(name, &blk)
      method_name = define_anon_query_scope(&blk)
      define_query_scope(name) do |*args|
        QueryBuilder::Deferred.new(self, method_name, args, name)
      end
    end
    
    def rewrite(*rules, &blk)
      options = rules.last.is_a?(Hash) ? rules.pop : {}
      
      if options[:in]
        context(options[:in]).rewrite(*rules, &blk)
        return
      end
      
      name = define_builder(&blk)
      
      rules << :wild if rules.empty?
      rules.each do |rule|
        @rewriters << [rule, name]
      end
    end
    
    private
    
    def define_context(name)
      @contexts[name] ||= begin      
        @builder.send(:define_method, "process_#{name}") do |*args|
          options = args.last.is_a?(Hash) ? args.pop : {}
          options[:in] = name
          args << options
          process(*args)
        end                     
        
        Context.new(@builder, self)
      end
    end
    
    def define_builder(&blk)
      define_anonymous(@builder, &blk)
    end
    
    def define_anon_query_scope(&blk)
      define_anonymous(@query_scope, &blk)
    end
    
    def define_query_scope(name, &blk)
      @query_scope.send(:define_method, name, &blk)
    end
    
    def define_anonymous(receiver, &blk)
      name = "__sexp_builder#{@builder.tmpid}"
      receiver.send(:define_method, name, &blk)
      name
    end
  end
end