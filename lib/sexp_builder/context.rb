class SexpBuilder
  class Context
    attr_reader :parent, :builder, :query_scope, :contexts, :rewriters
    
    def initialize(builder, parent = nil)
      @builder = builder
      @parent = parent
      
      @contexts  = {}
      @rewriters = []
      
      @query_scope = Module.new do
        include parent.query_scope if parent
      end
    end
    
    # Returns the top-most context.
    def main_context
      if @parent
        @parent.main_context
      else
        self
      end
    end
    
    # Defines or finds a sub-context, and evalutes the block under it. If you
    # want to process something under this context, you would have to call
    # <tt>process_{name}</tt>.
    def context(name, &blk)
      context = define_context(name.to_sym)
      context.instance_eval(&blk) if blk
      context
    end
    
    # Defines a matcher. A matcher is a bit of Ruby code which can be used in
    # your rules. The expression it should match is passed in, and it should
    # return a true-ish value if it matches. The matcher will be evaluated
    # under the instatiated processor, so you can use other instance methods
    # and instance variables too.
    #
    #   matcher :five_arguments do |exp|
    #     self             # => the instance of Example
    #     exp.length == 6  # the first will always be :arglist
    #   end
    # 
    # Under the hood, this will define:
    # 
    # * The block as +matcher_five_arguments+ on the builder.
    # * +five_arguments+, which will invoke the matcher, on the query scope.
    def matcher(name, &blk)
      method_name = "matcher_#{name}"
      define(method_name, &blk)
      
      define_query_scope(name) do
        block do |exp|
          instance.send(method_name, exp)
        end
      end
    end
    
    # Defines a rule. Rules are simply snippets of SexpPath which can refer to
    # each other and itself. They can also take arguments too.
    # 
    #   # Matches any number.
    #   rule :number do |capture_as|
    #     # Doesn't make very much sense to take an argument here,
    #     # it's just an example
    #     s(:lit, _ % capture_as)
    #   end
    #
    #   # Matches a sequence of plusses: 1 + 2 + 3
    #   rule :plus_sequence do
    #     s(:call,               # a method call
    #        number(:number) |   # the receiver can be a number
    #        plus_sequence,      # or a sequence   
    #       :+,
    #       s(:arglist,
    #        number(:number) |   # the argument can be a number
    #        plus_sequence       # or a sequence
    #   end
    # 
    # Under the hood, this will define:
    # 
    # * The blocks as +real_number+ and +real_plus_sequence+ on the 
    #   query_scope.
    # * +number+ and +plus_sequence+ which wraps the methods above as 
    #   QueryBuilder::Deferred.
    def rule(name, &blk)
      real_name = "real_#{name}"
      define_query_scope(real_name, &blk)
      define_query_scope(name) do |*args|
        QueryBuilder::Deferred.new(self, real_name, args, name)
      end
    end
    
    # Defines a rewriter. Rewriters take one or more rules and defines
    # replacements when they match. The data-object from SexpPath is given as
    # an argument. If you want some of the sub-expressions matched too, you'll
    # have to call process() yourself.
    #
    #   rewrite :plus_sequence do |data|
    #     # sum the numbers
    #     sum = data[:number].inject { |all, one| all + one }
    #     # return a new number
    #     s(:lit, sum)
    #   end
    # 
    # Under the hood, this will define:
    # 
    # * The block as +rewrite_plus_sequence+.
    # * And @rewriters will now include :plus_sequence.
    # 
    # You can also give this several rules, or none if you want it to match
    # every single Sexp.
    #
    # == Context shortcut
    #
    #   rewrite :foo, :in => :bar do
    #     ...
    #   end
    # 
    # Is the same as:
    #
    #   context :bar do
    #     rewrite :foo do
    #       ...
    #     end
    #   end
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