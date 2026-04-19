module GamesHelper
  def sound_paths
    Dir[Rails.root.join("app/assets/sounds/*.ogg")].each_with_object({}) do |f, h|
      name = File.basename(f, ".ogg")
      h[name] = asset_path(File.basename(f))
    end
  end
end
