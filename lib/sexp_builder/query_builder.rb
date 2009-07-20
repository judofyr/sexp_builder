class SexpBuilder
  class QueryBuilder < SexpPath::SexpQueryBuilder
    class Data < Hash
      def []=(key, value)
        if current = self[key]
          if current.class == Array
            current << value
          else
            super(key, [current, value])
          end
        else
          super
        end
      end
    end
    
    class Scope < SexpPath::Matcher::Base
      def initialize(type, instance)
        @type = type
        @instance = instance
      end
      
      def satisfy?(o, data={})
        if @instance.scope[1..-1].include?(@type)
          capture_match o, data
        end
      end
    end
    
    class Deferred < SexpPath::Matcher::Base
      def initialize(receiver, name, args, real_name)
        @receiver = receiver
        @name = name
        @args = args
        @real_name = real_name.to_s
      end
      
      def satisfy?(o, data={})
        @receiver.send(@name, *@args).satisfy?(o, data)
      end
      
      def inspect
        "rule(:#{@real_name}" 
      end
    end
    
    class Not < SexpPath::Matcher::Base
      def initialize(matcher)
        @matcher = matcher
      end
      
      def satisfy?(o, data={})
        unless @matcher.satisfy?(o)
          capture_match o, data
        end
      end
    end
    
    class << self
      attr_accessor :instance
      
      def make(context, instance)
        query_builder = Class.new(QueryBuilder) { extend context.query_scope }
        query_builder.instance = instance
        query_builder
      end
      
      def n(matcher)
        Not.new(matcher)
      end
      
      def scope(type)
        Scope.new(type, instance)
      end
      
      def block(&blk)
        SexpPath::Matcher::Block.new(&blk)
      end
    end
  end
end