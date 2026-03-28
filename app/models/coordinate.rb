class Coordinate
  attr_reader :row, :col

  def initialize(row, col)
    @row = Integer(row)
    @col = Integer(col)
    freeze
  end

  def self.from_key(str)
    new(*str.tr("[]", "").split(", ").map(&:to_i))
  end

  def to_key = "[#{row}, #{col}]"
  def to_a   = [ row, col ]
  def to_s   = inspect
  def inspect = "#<Coordinate [#{row}, #{col}]>"

  def ==(other)   = other.is_a?(Coordinate) && row == other.row && col == other.col
  def eql?(other) = self == other
  def hash        = [ row, col ].hash
end
