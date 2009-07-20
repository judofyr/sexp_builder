class Andand < SexpBuilder
  
  # This matches foo.andand:     
  rule :andand_base do
    s(:call,          # a method call
      _ % :receiver,  # the receiver
      :andand,        # the method name
      s(:arglist))    # the arguments
  end
  
  # This matches foo.andand.bar
  rule :andand_call do
    s(:call,         # a method call
      andand_base,   # foo.andand
      _ % :name,     # the method name
      _ % :args)     # the arguments
  end
  
  # This matches foo.andand.bar { |args| block }
  rule :andand_iter do
    s(:iter,           # a block
      andand_call,     # the method call
      _ % :blockargs,  # the arguments passed to the block
      _ % :block)      # content of the block
  end
  
  # This will rewrite:
  #
  #   foo.andand.bar     => (tmp = foo) && tmp.bar
  #   foo.andand.bar { } => (tmp = foo) && tmp.bar { }
  # 
  rewrite :andand_call, :andand_iter do |data|
    # get a tmpvar (see below for definition)
    tmp = tmpvar
    
    # tmp = foo
    assign = s(:lasgn, tmp, process(data[:receiver]))
    
    # tmp.bar
    call   = s(:call, s(:lasgn, tmp), data[:name], process(data[:args]))
    
    # tmp.bar { }
    if data[:block]
      call = s(:iter,
               call,
               process(data[:blockargs]),
               process(data[:block]))
    end
    
    # (tmp = foo) && tmp.bar
    s(:and,
      assign,
      call)
  end
  
  ## Other methods
  
  def initialize
    @tmp = 0
    super           # don't forget to call super!
  end
  
  # Generates a random variable.
  def tmpvar
    "__andand_#{@tmp += 1}".to_sym
  end
end