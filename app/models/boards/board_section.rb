module Boards
  class BoardSection
    SECTIONS = [
      # 0: Farm
      {
        map: [
          "DDCWWTTTGG",
          "DSCWTTTLGG",
          "CCCFFFTCFF",
          "CCFFWDDCCF",
          "CGGWFFDDCC",
          "GGLFWFWDDC",
          "GGGTFFWWDD",
          "GGTTMWWWDW",
          "GMTTWWWWWW",
          "TTTWWWWWWW"
        ],
        silver_hexes: [
          { r: 1, c: 1, k: "Castle" }
        ],
        location_hexes: [
          { r: 1, c: 7, k: "Farm" },
          { r: 5, c: 2, k: "Farm" }
        ]
      },
      # 1: Oasis
      {
        map: [
          "DDCWWTTGGG",
          "DCWFFTTTGG",
          "DDWFFTTLFG",
          "WWWFGTFFFF",
          "WWWWGGGGFF",
          "WTTWGGCCDC",
          "WTCTWGCCDC",
          "WSCFWLDDCW",
          "WWCFWWWDDW",
          "WWWWWWWWWW"
        ],
        silver_hexes: [
          { r: 7, c: 1, k: "Castle" }
        ],
        location_hexes: [
          { r: 2, c: 7, k: "Oasis" },
          { r: 7, c: 5, k: "Oasis" }
        ]
      },
      # 2: Oracle
      {
        map: [
          "GGGTTWGTTT",
          "GGGSTWGTTT",
          "GFFGTTWGGT",
          "FFCGTWFLTT",
          "FFFCCWFFWW",
          "MMCGGWWWDD",
          "CCCMGFFFDD",
          "CCSDMDFFCC",
          "WWWDDDDMCC",
          "WWWWDDDDDC"
        ],
        silver_hexes: [
          { r: 1, c: 3, k: "Castle" },
          { r: 7, c: 2, k: "Castle" }
        ],
        location_hexes: [
          { r: 3, c: 7, k: "Oracle" }
        ]
      },
      # 3: Tower
      {
        map: [
          "TTTTMMGMCC",
          "TMTTFGMMMC",
          "FFTFFFGGWM",
          "DFFFWLGWMM",
          "DDDDFWGWCC",
          "DCDDDWWCGC",
          "DDCDDWFSGC",
          "CCLDWFFFGG",
          "DCWWWTTFGG",
          "DCCWTTTGGG"
        ],
        silver_hexes: [
          { r: 6, c: 7, k: "Castle" }
        ],
        location_hexes: [
          { r: 3, c: 5, k: "Tower" },
          { r: 7, c: 2, k: "Tower" }
        ]
      },
      # 4: Tavern
      {
        map: [
          "FDDMMDDCCC",
          "FFDDDMMCCC",
          "FFFFFFFMMM",
          "WWFSGGTTMM",
          "FFWWGGGTTC",
          "FCCWGTTCCC",
          "DFLCWTTLCG",
          "DDCWTTGGGG",
          "DDDWTTTGGG",
          "DDWWTTTGGG"
        ],
        silver_hexes: [
          { r: 3, c: 3, k: "Castle" }
        ],
        location_hexes: [
          { r: 6, c: 2, k: "Tavern" },
          { r: 6, c: 7, k: "Tavern" }
        ]
      },
      # 5: Paddock
      {
        map: [
          "CCCDDWDDDD",
          "MMCDDWDDDD",
          "MMCMMWDDLF",
          "MCMMWMDFFF",
          "CCTTWMMCFF",
          "CTTWCCCMFF",
          "CLTTWFFFFF",
          "GGTWGSGFGT",
          "GGTTWGGGGT",
          "GGTTWGGGTT"
        ],
        silver_hexes: [
          { r: 7, c: 5, k: "Castle" }
        ],
        location_hexes: [
          { r: 2, c: 8, k: "Paddock" },
          { r: 6, c: 1, k: "Paddock" }
        ]
      },
      # 6: Barn
      {
        map: [
          "CDDDDDDDDD",
          "CCCDDDDDCD",
          "MMMDMMLDDC",
          "CMMMMMFFCC",
          "CCCMMWFFFC",
          "GCCCMFFWTC",
          "GGLTTFWFFT",
          "GGTTFFGSTT",
          "GGGTTWGGTT",
          "GGGTWGGTTT"
        ],
        silver_hexes: [
          { r: 7, c: 7, k: "Castle" }
        ],
        location_hexes: [
          { r: 2, c: 6, k: "Barn" },
          { r: 6, c: 2, k: "Barn" }
        ]
      },
      # 7: Harbor
      {
        map: [
          "GGTTTWGTTF",
          "GFTTWGTTFF",
          "GFFTWGGFFF",
          "FFTTWGMFDD",
          "CFSTWGDDDD",
          "CCTWGGMMDD",
          "CCWWWGDDDC",
          "WWGGWWLCMC",
          "WDSGWMWCCC",
          "WDDWWWWCCC"
        ],
        silver_hexes: [
          { r: 4, c: 2, k: "Castle" },
          { r: 8, c: 2, k: "Castle" }
        ],
        location_hexes: [
          { r: 7, c: 6, k: "Harbor" }
        ]
      },
      # 8: Caravan
      {
        map: [
          "WWGGWWWFFF",
          "WGGTWWWFFF",
          "WWWGTWWDDF",
          "TTWSTWDMFF",
          "TTTWWWDDGG",
          "TTTTCDGGGG",
          "TTLCCCGGMG",
          "TCCCCGLDDG",
          "CMCCCFFFDD",
          "CCCFFFFDDD"
        ],
        silver_hexes: [
          { r: 3, c: 3, k: "Nomad" }
        ],
        location_hexes: [
          { r: 6, c: 2, k: "Caravan" },
          { r: 7, c: 6, k: "Caravan" }
        ]
      },
      # 9: Garden
      {
        map: [
          "CCCWWWWDDD",
          "CCCWLFDDMD",
          "CCCCCCFDMD",
          "CGGCCMFMDD",
          "CGGGDMMFFF",
          "TFGLDDFFFF",
          "TTFFDMFGGF",
          "TTMFMTSGGG",
          "TMTTTTWWGG",
          "TTTTWWWGGG"
        ],
        silver_hexes: [
          { r: 7, c: 6, k: "Nomad" }
        ],
        location_hexes: [
          { r: 1, c: 4, k: "Garden" },
          { r: 5, c: 3, k: "Garden" }
        ]
      },
      # 10: Quarry
      {
        map: [
          "GGGWWWMCCC",
          "GGWTDWWWCC",
          "GMWTLDDDWM",
          "FWTTCCDFFF",
          "FWGGCCDDMF",
          "FWSGCCDSFF",
          "FFWGCCCFFF",
          "DWGGCSTTFF",
          "DDWWGTTMTT",
          "DDDWWTMTTT"
        ],
        silver_hexes: [
          { r: 5, c: 2, k: "Nomad" },
          { r: 5, c: 7, k: "Nomad" },
          { r: 7, c: 5, k: "Nomad" }
        ],
        location_hexes: [
          { r: 2, c: 4, k: "Quarry" }
        ]
      },
      # 11: Village
      {
        map: [
          "DDDDDDDGGG",
          "DDDMDFFFGG",
          "DMDDDFWFGT",
          "CFWDSWFTTT",
          "CFFWWWFLCT",
          "CFFFWWFCCC",
          "CCCLTWWFMC",
          "GCGGTWFCCC",
          "GGGGTTTTCM",
          "GGGTTTTTMM"
        ],
        silver_hexes: [
          { r: 3, c: 4, k: "Nomad" }
        ],
        location_hexes: [
          { r: 4, c: 7, k: "Village" },
          { r: 6, c: 3, k: "Village" }
        ]
      },
      # 12: Lighthouse / Forester's Lodge
      {
        map: [
          "TTTTWWFFFF",
          "TTTTWDFFFF",
          "CTTTTWDSDM",
          "CCLTWDDDDW",
          "CCCCWWWWWW",
          "WWWWWWDDDW",
          "FFFFWGLDDD",
          "FMGWGGGGMC",
          "FGGWGGGCMC",
          "GGGWWWCCCC"
        ],
        silver_hexes: [
          { r: 2, c: 7, k: "Castle" }
        ],
        location_hexes: [
          { r: 6, c: 6, k: "Lighthouse" },
          { r: 3, c: 2, k: "ForestersLodge" }
        ]
      },
      # 13: Barracks / Crossroads
      {
        map: [
          "GGTTWWTTGG",
          "GGTTWGGCGG",
          "GFFTTTTCCG",
          "FFFLDTTCCC",
          "FFFFFDTLMC",
          "FFFDDMCCCC",
          "FFFMDDDCCC",
          "FFDDSDDCMC",
          "GGDDDWWDGG",
          "GGDWWWDDGG"
        ],
        silver_hexes: [
          { r: 7, c: 4, k: "Castle" }
        ],
        location_hexes: [
          { r: 3, c: 3, k: "Barracks" },
          { r: 4, c: 7, k: "Crossroads" }
        ]
      },
      # 14: City Hall / Fort
      {
        map: [
          "TTTTWWDDDD",
          "TTFFFGGDDD",
          "MMTFFLGMCD",
          "TTMMGGGCCM",
          "TTSFGMMCCC",
          "TTTFMMCCMC",
          "MMTFFFLCCC",
          "FFFMGGDWCM",
          "FFWGGGDDDD",
          "FGGGGGGDDD"
        ],
        silver_hexes: [
          { r: 4, c: 2, k: "Castle" }
        ],
        location_hexes: [
          { r: 2, c: 5, k: "CityHall" },
          { r: 6, c: 6, k: "Fort" }
        ]
      },
      # 15: Monastery / Wagon
      {
        map: [
          "MDDDMWMGGG",
          "DDDMWFFFGG",
          "DDDDWFFLGW",
          "MCDDWFFGWW",
          "MCCDDWFWWW",
          "MCCGGWWCCC",
          "CCCSGTTTCC",
          "CFGGGTTTCM",
          "FFFGTTTTLM",
          "FFTTTTMMMM"
        ],
        silver_hexes: [
          { r: 6, c: 3, k: "Castle" }
        ],
        location_hexes: [
          { r: 2, c: 7, k: "Monastery" },
          { r: 8, c: 8, k: "Wagon" }
        ]
      }
    ].freeze

    attr_accessor :terrain
    attr_accessor :content
    attr_reader :flipped, :id

    def initialize(id, flipped)
      data = SECTIONS[id] || raise(ArgumentError, "Unknown board id: #{id}")
      @id = id
      @flipped = flipped
      @raw_silver_hexes = data[:silver_hexes]
      @raw_location_hexes = data[:location_hexes]
      map_data = @flipped == 0 ? data[:map] : data[:map].reverse.map(&:reverse)
      @terrain = Array.new(10) { Array.new(10) }
      map_data.each_with_index do |line, r|
        10.times { |c| @terrain[r][c] = line[c] }
      end
    end

    def terrain_at(row, column)
      @terrain[row][column]
    end

    def silver_hexes
      flip_hexes(@raw_silver_hexes)
    end

    def silver_hex_kind(row, col)
      silver_hexes.find { |h| h[:r] == row && h[:c] == col }&.dig(:k)
    end

    def location_hexes
      flip_hexes(@raw_location_hexes)
    end

    private

    def flip_hexes(hexes)
      return hexes if @flipped == 0
      hexes.map { |h| h.merge(r: 9 - h[:r], c: 9 - h[:c]) }
    end
  end
end
