class BasicBlockNode < Node
  property! block
  @block : LLVM::BasicBlock?

  def initialize(@line : Int32, @position : Int32)
    @value = nil
    @children = [] of Node
  end

  def pre_walk(state : ProgramState) : Nil
    # Generate unique block name
    block_name = "block#{state.blocks.size + 1}"

    # Put block into active function and make block active
    self_block = state.active_function.basic_blocks.append block_name
    state.add_block block_name, self_block
    state.active_block = self_block
    @block = self_block

    # If this block is a child of a function, allocate function parameters inside block
    if parent.class == FunctionDeclarationNode
      alloca_func_params state
    end
  end

  def resolve_value(state : ProgramState) : Nil
    @resolved_value = @children[-1].resolved_value
    # If parent node is an If or While Expression...
    if parent.is_a?(IfExpressionNode) || parent.is_a?(WhileExpressionNode)
      # Get the block of the last If or While Node inside block or use own block
      scope = block
      @children.each do |child|
        if child.class == IfExpressionNode
          scope = child.as(IfExpressionNode).exit_block
        elsif child.class == WhileExpressionNode
          scope = child.as(WhileExpressionNode).exit_block
        end
      end

      # If last child node is not a return statement, add jump statements for control flow
      if !@children[-1].is_a?(ReturnNode)
        if parent.is_a?(IfExpressionNode)
          state.close_statements.push JumpStatement.new scope, parent.as(IfExpressionNode).exit_block
        elsif parent.is_a?(WhileExpressionNode)
          state.close_statements.push JumpStatement.new scope, parent.as(WhileExpressionNode).cond_block
        end
      end
    end
  end

  def alloca_func_params(state : ProgramState) : Nil
    counter = 0
    parent.as(FunctionDeclarationNode).params.each do |var, type_val|
      state.builder.position_at_end state.active_block
      case type_val
      when :Int32, :Float64, :Bool
        ptr : LLVM::Value
        if type_val == :Int32
          ptr = state.builder.alloca state.int32, var
        elsif type_val == :Float64
          ptr = state.builder.alloca state.double, var
        else
          ptr = state.builder.alloca state.int1, var
        end
        state.builder.store state.active_function.params[counter], ptr
        state.variable_pointers[state.active_function][var] = ptr
      when :String
      else
        raise "Unable to alloca function declaration parameter #{var} of type #{type_val}"
      end
      counter += 1
    end
  end
end
