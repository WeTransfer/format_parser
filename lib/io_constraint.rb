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
  
  def read(n_bytes)
    @io.read(n_bytes)
  end
  
  def seek(absolute_offset)
    @io.seek(absolute_offset)
  end
  
  def size
    @io.size
  end
end
