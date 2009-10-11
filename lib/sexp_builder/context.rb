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
    
    def main_context
      if @parent
        @parent.main_context
      else
        self
      end
    end
    
    def context(name, &blk)
      context = define_context(name.to_sym)
      context.instance_eval(&blk) if blk
      context
    end
    
    def matcher(name, &blk)
      method_name = "matcher_#{name}"
      define(method_name, &blk)
      
      define_query_scope(name) do
        block do |exp|
          instance.send(method_name, exp)
        end
      end
    end
    
    def rule(name, &blk)
      real_name = "real_#{name}"
      define_query_scope(real_name, &blk)
      define_query_scope(name) do |*args|
        QueryBuilder::Deferred.new(self, real_name, args, name)
      end
    end
    
    def rewrite(*rules, &blk)
      options = rules.last.is_a?(Hash) ? rules.pop : {}
      rules << :wild if rules.empty?
      
      return context(options[:in]).rewrite(*rules, &blk) if options[:in]
      
      rules.each do |rule|
        @rewriters << rule
        define("rewrite_#{rule}", &blk)
      end
    end
    
    private
    
    def define_context(name)
      @contexts[name] ||= begin      
        context = Context.new(@builder, self)
        
        define("process_#{name}") do |*args|
          begin
            prev, @context = @context, context
            process(*args)
          ensure
            @context = prev
          end
        end                  
        
        context
      end
    end
    
    def define_query_scope(name, &blk)
      @query_scope.send(:define_method, name, &blk)
    end
    
    def define(name, &blk)
      @builder.send(:define_method, name, &blk)
    end
  end
end