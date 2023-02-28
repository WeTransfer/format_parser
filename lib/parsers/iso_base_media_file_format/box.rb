module FormatParser
  module ISOBaseMediaFileFormat
    class Box
      attr_reader :type, :position, :size, :fields, :children

      def initialize(type, position, size, fields = nil, children = nil)
        @type = type
        @position = position
        @size = size
        @fields = fields || {}
        @children = children || []
      end

      # Return all children with one of the given type(s).
      #
      # @param [Array<String>] types The box type(s) to search for.
      # @return [Array<Box>]
      def all_children(*types)
        children.select { |child| types.include?(child.type) }
      end

      # Returns true if there are one or more children with the given type.
      #
      # @param [String] type The box type to search for.
      # @return [Boolean]
      def child?(type)
        children.any? { |child| child.type == type }
      end

      # Return the first child with one of the given types.
      #
      # @param [Array<String>] types The box type(s) to search for.
      # @return [Box, nil]
      def first_child(*types)
        children.find { |child| types.include?(child.type) }
      end

      # Find and return all descendents of a given type.
      #
      # @param [Array<String>] types The box type(s) to search for.
      # @return [Array<Box>]
      def all_descendents(*types)
        children.map do |child|
          descendents = child.all_descendents(*types)
          types.include?(child.type) ? [child] + descendents : descendents
        end.flatten
      end

      # Find and return all descendents that exists at the given path.
      #
      # @param [Array<String>] path The path to search at.
      # @return [Array<Box>]
      def all_descendents_by_path(path)
        return [] if path.empty?
        next_type, *remaining_path = path
        matching_children = all_children(next_type)
        return matching_children if remaining_path.empty?
        matching_children.map { |child| child.all_descendents_by_path(remaining_path) }.flatten
      end

      # Find and return the first descendent (using depth-first search) of a given type.
      #
      # @param [Array<String>] types The box type(s) to search for.
      # @return [Box, nil]
      def first_descendent(*types)
        children.each do |child|
          return child if types.include?(child.type)
          if (descendent = child.first_descendent(*types))
            return descendent
          end
        end
        nil
      end

      # Find and return the first descendent that exists at the given path.
      #
      # @param [Array<String>] path The path to search at.
      # @return [Box, nil]
      def first_descendent_by_path(path)
        all_descendents_by_path(path)[0]
      end
    end
  end
end
