# We deliberately want to document and restrict the
# number of methods an IO-ish object has to implement
# to be usable with all our parsers. This subset is fairly
# thin and well defined, and all the various IO limiters
# and cache facilities in the library are guaranteed to
# support those methods. This wrapper is used to guarantee
# that the parser can only call those specific methods and
# nothing more. Consequently, if the parser uses a gem that
# for some reason needs additional IO methods to be available
# this parser has to provide it's own extensions to that end.
#
# The rationale for including a method in this subset is as follows:
# we include a method if other methods can be implemented on top of it.
# For example, should some parser desire `IO#readbyte`, it can be
# implemented in terms of a `read()`. Idem for things like `IO#eof?`,
# `IO#rewind` and friends.
class FormatParser::IOConstraint
  def initialize(io)
    @io = io
  end

  # Returns at most `n_bytes` of data from the IO or less if less data was available
  # before the EOF was hit
  #
  # @param n_bytes[Integer]
  # @return [String, nil] the content read from the IO or `nil` if no data was available
  def read(n_bytes)
    @io.read(n_bytes)
  end

  # Seeks the IO to the given absolute offset from the start of the file/resource
  #
  # @param to[Integer] offset in the IO
  # @return Integer
  def seek(to)
    @io.seek(to)
  end

  # Returns the size of the resource contained in the IO
  #
  # @return Integer
  def size
    @io.size
  end

  # Returns the current position/offset within the IO
  #
  # @return Integer
  def pos
    @io.pos
  end
end
