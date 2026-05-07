class Turn
  class SubPhase
    def complete? = @complete == true

    def handle(_action_name, **_kwargs)
      raise NotImplementedError, "#{self.class} must implement #handle"
    end

    def to_h
      raise NotImplementedError, "#{self.class} must implement #to_h"
    end

    def self.from_h(_hash)
      raise NotImplementedError, "#{self} must implement .from_h"
    end
  end
end
