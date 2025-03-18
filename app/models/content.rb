class Content
  attr_accessor :content_objects

  def initialize(board_contents)
    @content_objects = Array.new(20) { Array.new(20) }
    board_contents.each_with_index do |item, n|
      Rails.logger.info "  adding #{item.inspect}"
      k = item.first
      k = JSON.parse(k) if k.is_a? String
      v = item.last
      Rails.logger.info "  -> #{k} => #{v}"
      @content_objects[k[0].to_i][k[1].to_i] =
        v["klass"].constantize.new(v["qty"])
    end
  end

  def content_at(row, column)
    @content_objects[row][column]
  end
end
