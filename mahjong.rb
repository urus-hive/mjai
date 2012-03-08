require "json"
autoload :TenhouMjlogLoader, "./tenhou_mjlog_loader"


class Pai
    
    include(Comparable)
    
    TSUPAI_STRS = " ESWNPFC".split(//)
    
    def self.parse_pais(str)
      type = nil
      pais = []
      red = false
      str.split(//).reverse_each() do |ch|
        next if ch =~ /^\s$/
        if ch =~ /^[mps]$/
          type = ch
        elsif ch =~ /^[1-9]$/
          raise(ArgumentError, "type required after number") if !type
          pais.push(Pai.new(type, ch.to_i(), red))
          red = false
        elsif TSUPAI_STRS.include?(ch)
          pais.push(Pai.new(ch))
        elsif ch == "r"
          red = true
        else
          raise(ArgumentError, "unexpected character: %s", ch)
        end
      end
      return pais.reverse()
    end
    
    def self.dump_pais(pais)
      return pais.map(){ |pai| "%-3s" % pai }.join("")
    end
    
    def initialize(*args)
      case args.size
        when 1
          str = args[0]
          if str == "?"
            @type = @number = nil
            @red = false
          elsif str =~ /^([1-9])([mps])(r)?$/
            @type = $2
            @number = $1.to_i()
            @red = $3 != nil
          elsif number = TSUPAI_STRS.index(str)
            @type = "t"
            @number = number
            @red = false
          else
            raise(ArgumentError, "unknown pai string: %s" % str)
          end
        when 2, 3
          (@type, @number, @red) = args
          @red = false if @red == nil
        else
          raise(ArgumentError, "wrong number of args")
      end
    end
    
    def to_s()
      if !@type
        return "?"
      elsif @type == "t"
        return TSUPAI_STRS[@number]
      else
        return "%d%s%s" % [@number, @type, @red ? "r" : ""]
      end
    end
    
    def inspect
      return "Pai[%s]" % self.to_s()
    end
    
    attr_reader(:type, :number)
    
    def red?
      return @red
    end
    
    def yaochu?
      return @type == "t" || @number == 1 || @number == 9
    end
    
    def fonpai?
      return @type == "t" && (1..4).include?(@number)
    end
    
    def sangenpai?
      return @type == "t" && (5..7).include?(@number)
    end
    
    def data
      return [@type, @number, @red ? 1 : 0]
    end
    
    def ==(other)
      return self.class == other.class && self.data == other.data
    end
    
    alias eql? ==
    
    def hash()
      return self.data.hash()
    end
    
    def <=>(other)
      if self.class == other.class
        return self.data <=> other.data
      else
        raise(ArgumentError, "invalid comparison")
      end
    end
    
    def remove_red()
      return Pai.new(@type, @number)
    end
    
    def same_symbol?(other)
      return @type == other.type && @number == other.number
    end
    
    # Next pai in terms of dora derivation.
    def succ
      if (@type == "t" && @number == 7) || (@type != "t" && @number == 9)
        number = 1
      else
        number = @number + 1
      end
      return Pai.new(@type, number)
    end
    
    UNKNOWN = Pai.new(nil, nil)
    
end


#pais = Pai.parse_pais("123m4p5pr6p789sESWNPFC")
#p pais
#p pais.map(){ |h| [h.type, h.number, h.red?] }


module WithFields
    
    def define_fields(names)
      @@field_names = names
      @@field_names.each() do |name|
        define_method(name) do
          return @fields[name]
        end
      end
    end
    
end


class Serializable
    
    def self.define_fields(specs)
      @@field_specs = specs
      @@field_specs.each() do |name, type|
        define_method(name) do
          return @fields[name]
        end
      end
    end
    
    def self.from_json(json, board)
      hash = JSON.parse(json)
      fields = {}
      for name, type in @@field_specs
        plain = hash[name.to_s()]
        next if !plain
        case type
          when :symbol
            obj = plain.intern()
          when :symbols
            obj = plain.map(){ |s| s.intern() }
          when :player
            obj = board.players[plain]
          when :pai
            obj = Pai.new(plain)
          when :pais
            obj = plain.map(){ |s| Pai.new(s) }
          when :number, :numbers, :string, :strings
            obj = plain
          else
            raise("unknown type")
        end
        fields[name] = obj
      end
      return new(fields)
    end
    
    def initialize(fields)
      for k, v in fields
        if !@@field_specs.any?(){ |n, t| n == k }
          raise(ArgumentError, "unknown field: %p" % k)
        end
      end
      @fields = fields
    end
    
    def to_json()
      hash = {}
      for name, type in @@field_specs
        obj = @fields[name]
        next if !obj
        case type
          when :symbol, :pai
            plain = obj.to_s()
          when :player
            plain = obj.id
          when :symbols, :pais
            plain = obj.map(){ |a| a.to_s() }
          when :number, :numbers, :string, :strings
            plain = obj
          else
            raise("unknown type")
        end
        hash[name.to_s()] = plain
      end
      return JSON.dump(hash)
    end
    
end


# 副露
class Furo
    
    extend(WithFields)
    
    define_fields([:type, :taken, :consumed, :target])
    
    def initialize(fields)
      @fields = fields
    end
    
    def pais
      return (self.taken ? [self.taken] : []) + self.consumed
    end
    
    def to_s()
      if self.type == :ankan
        return '[# %s %s #]' % self.consumed[0, 2]
      else
        return "[%s(%d)/%s]" % [self.taken, self.target.id, self.consumed.join(" ")]
      end
    end
    
end


class Action < Serializable
    
    define_fields([
      [:type, :symbol],
      [:reason, :symbol],
      [:actor, :player],
      [:target, :player],
      [:pai, :pai],
      [:consumed, :pais],
      [:pais, :pais],
      [:id, :number],
      [:oya, :player],
      [:dora_marker, :pai],
      [:uri, :string],
      [:names, :strings],
      [:fu, :number],
      [:fan, :number],
      [:hora_points, :number],
      [:deltas, :numbers],
      [:player_points, :numbers],
    ])
    
end


class Player
    
    def initialize()
      @points = 25000
    end
    
    attr_reader(:id)
    attr_reader(:name)
    attr_reader(:tehais)  # 手牌
    attr_reader(:furos)  # 副露
    attr_reader(:ho)  # 河 (鳴かれた牌を含まない)
    attr_reader(:sutehais)  # 捨牌 (鳴かれた牌を含む)
    attr_reader(:extra_anpais)  # sutehais以外のこのプレーヤに対する安牌
    attr_reader(:reach_ho_index)
    attr_accessor(:board)
    attr_accessor(:points)
    
    def anpais
      return @sutehais + @extra_anpais
    end
    
    def reach?
      return @reach
    end
    
    def process_action(action)
      
      if @board.previous_action &&
          @board.previous_action.type == :dahai &&
          @board.previous_action.actor != self &&
          action.type != :hora
        @extra_anpais.push(@board.previous_action.pai)
      end
      
      case action.type
        when :start_game
          @id = action.id
          @name = action.names[@id] if action.names
        when :start_kyoku
          @tehais = []
          @furos = []
          @ho = []
          @sutehais = []
          @extra_anpais = []
          @reach = false
          @reach_ho_index = nil
      end
      
      if action.actor == self
        case action.type
          when :haipai
            @tehais = action.pais.sort()
          when :tsumo
            @tehais.push(action.pai)
          when :dahai
            delete_tehai(action.pai)
            @tehais.sort!()
            @ho.push(action.pai)
            @sutehais.push(action.pai)
            @extra_anpais.clear() if !@reach
          when :chi, :pon, :daiminkan, :ankan
            for pai in action.consumed
              delete_tehai(pai)
            end
            @furos.push(Furo.new({
              :type => action.type,
              :taken => action.pai,
              :consumed => action.consumed,
              :target => action.target,
            }))
          when :kakan
            delete_tehai(action.pai)
            pon_index = @furos.index(){ |f| f.type == :pon && f.taken.same_symbol?(action.pai) }
            raise("should not happen") if !pon_index
            @furos[pon_index] = Furo.new({
              :type => :kakan,
              :taken => @furos[pon_index].taken,
              :consumed => @furos[pon_index].consumed + [action.pai],
              :target => @furos[pon_index].target,
            })
          when :reach_accepted
            @reach = true
            @reach_ho_index = @ho.size - 1
            @points -= 1000
        end
      end
      
      if action.target == self
        case action.type
          when :chi, :pon, :daiminkan, :ankan
            pai = @ho.pop()
            raise("should not happen") if pai != action.pai
        end
      end
      
    end
    
    def jikaze
      if @board.oya
        return Pai.new("t", 1 + (4 + @id - @board.oya.id) % 4)
      else
        return nil
      end
    end
    
    def tenpai?
      return ShantenCounter.new(@tehais, 0).shanten <= 0
    end
    
    def delete_tehai(pai)
      pai_index = @tehais.index(pai) || @tehais.index(nil)
      raise("should not happen") if !pai_index
      @tehais.delete_at(pai_index)
    end
    
    def create_action(params = {})
      return Action.new({:actor => self}.merge(params))
    end
    
    def inspect
      return "\#<%p:%d>" % [self.class, self.id]
    end
    
end


class PuppetPlayer < Player
    
    def respond_to_action(action)
      return nil
    end
    
end


class TsumogiriPlayer < Player
    
    def respond_to_action(action)
      case action.type
        when :tsumo, :chi, :pon
          if action.actor == self
            return create_action({:type => :dahai, :pai => self.tehais[-1]})
          end
      end
      return nil
    end
    
end


class ShantenPlayer < Player
    
    USE_FURO = false
    
    def respond_to_action(action)
      
      if action.actor == self
        
        case action.type
          
          when :tsumo, :chi, :pon, :reach
            shanten = ShantenCounter.new(self.tehais).shanten
            if action.type == :tsumo
              case shanten
                when -1
                  return create_action({:type => :hora, :target => action.actor, :pai => action.pai})
                when 0
                  return create_action({:type => :reach}) if !self.reach?
              end
              for pai in self.tehais
                if self.tehais.select(){ |tp| tp == pai }.size >= 4
                  #@board.last = true
                  return create_action({:type => :ankan, :consumed => [pai] * 4})
                end
              end
              pon = self.furos.find(){ |f| f.type == :pon && f.taken == action.pai }
              if pon
                #@board.last = true
                return create_action(
                    {:type => :kakan, :pai => action.pai, :consumed => [action.pai] * 3})
              end
            end
            sutehai = self.tehais[-1]
            (self.tehais.size - 1).downto(0) do |i|
              remains = self.tehais.dup()
              remains.delete_at(i)
              if ShantenCounter.new(remains, shanten).shanten == shanten
                sutehai = self.tehais[i]
                break
              end
            end
            p [:shanten, @id, shanten]
            return create_action({:type => :dahai, :pai => sutehai})
            
        end
        
      else  # action.actor != self
        
        case action.type
          when :dahai
            if ShantenCounter.new(self.tehais + [action.pai]).shanten == -1
              return create_action({:type => :hora, :target => action.actor, :pai => action.pai})
            elsif USE_FURO
              if self.tehais.select(){ |pai| pai == action.pai }.size >= 3
                #@board.last = true
                return create_action({
                  :type => :daiminkan,
                  :pai => action.pai,
                  :consumed => [action.pai] * 3,
                  :target => action.actor
                })
              elsif self.tehais.select(){ |pai| pai == action.pai }.size >= 2
                return create_action({
                  :type => :pon,
                  :pai => action.pai,
                  :consumed => [action.pai] * 2,
                  :target => action.actor
                })
              elsif (action.actor.id + 1) % 4 == self.id && action.pai.type != "t"
                for i in 0...3
                  consumed = (((-i)...(-i + 3)).to_a() - [0]).map() do |j|
                    Pai.new(action.pai.type, action.pai.number + j)
                  end
                  if consumed.all?(){ |pai| self.tehais.index(pai) }
                    return create_action({
                      :type => :chi,
                      :pai => action.pai,
                      :consumed => consumed,
                      :target => action.actor,
                    })
                  end
                end
              end
            end
        end
        
      end
      
      return nil
    end
    
end


class PipePlayer < Player
    
    def initialize(command)
      super()
      @io = IO.popen(command, "r+")
      @io.sync = true
    end
    
    def respond_to_action(action)
      @io.puts(action.to_json())
      response = Action.from_json(@io.gets().chomp(), self.board)
      return response.type == :none ? nil : response
    end
    
end


class Board
    
    def initialize(players)
      @game_type = :one_kyoku
      @players = players
      for player in @players
        player.board = self
      end
      @bakaze = nil
      @oya = nil
      @dora_markers = nil
      @previous_action = nil
    end
    
    attr_reader(:players)
    attr_accessor(:game_type)
    attr_reader(:all_pais)
    attr_reader(:bakaze)
    attr_reader(:oya)
    attr_reader(:honba)
    attr_reader(:dora_markers)  # ドラ表示牌
    attr_reader(:previous_action)
    attr_reader(:all_pais)
    attr_accessor(:last)  # kari
    
    def on_action(&block)
      @on_action = block
    end
    
    def do_action(action)
      
      if action.is_a?(Hash)
        action = Action.new(action)
      end
      @actor = action.actor if action.actor
      
      case action.type
        when :start_game
          # TODO change this by red config
          pais = (0...4).map() do |i|
            ["m", "p", "s"].map(){ |t| (1..9).map(){ |n| Pai.new(t, n, n == 5 && i == 0) } } +
                (1..7).map(){ |n| Pai.new("t", n) }
          end
          @all_pais = pais.flatten().sort()
        when :start_kyoku
          if action.oya == @oya  # 連荘
            @honba += 1
          else
            if action.oya.id == 0
              @bakaze = @bakaze ? @bakaze.succ : Pai.new("E")
            end
            @honba = 0
          end
          @oya = action.oya
          @dora_markers = [action.dora_marker]
        when :dora
          @dora_markers.push(action.dora_marker)
      end
      
      actions = (0...4).map(){ |i| action_in_view(action, i) }
      for i in 0...4
        @players[i].process_action(actions[i])
      end
      
      @on_action.call(action) if @on_action
      
      responses = (0...4).map(){ |i| @players[i].respond_to_action(actions[i]) }
      validate_responses(responses, action)
      
      @previous_action = action
      return responses
      
    end
    
    def action_in_view(action, player_id)
      player = @players[player_id]
      case action.type
        when :start_game
          return Action.new({:type => :start_game, :id => player_id, :names => action.names})
        when :haipai
          pais = action.actor == player ? action.pais : [Pai::UNKNOWN] * action.pais.size
          return Action.new({:type => :haipai, :actor => action.actor, :pais => pais})
        when :tsumo
          pai = action.actor == player ? action.pai : Pai::UNKNOWN
          return Action.new({:type => :tsumo, :actor => action.actor, :pai => pai})
        else
          return action
      end
    end
    
    def validate_responses(responses, action)
      for i in 0...4
        response = responses[i]
        raise("invalid actor") if response && response.actor != @players[i]
        is_actor = @players[i] == action.actor
        if expect_response_from?(@players[i])
          case action.type
            when :start_game, :start_kyoku, :haipai, :end_kyoku, :end_game,
                :hora, :ryukyoku, :dora, :reach_accepted
              valid = !response
            when :tsumo
              if is_actor
                valid = response && [:dahai, :reach, :ankan, :kakan, :hora].include?(response.type)
              else
                valid = !response
              end
            when :dahai
              if is_actor
                valid = !response
              else
                valid = !response || [:chi, :pon, :daiminkan, :hora].include?(response.type)
              end
            when :chi, :pon, :reach
              if is_actor
                valid = response && response.type == :dahai
              else
                valid = !response
              end
            when :ankan, :daiminkan
              # Actor should wait for tsumo.
              valid = !response
            when :kakan
              if is_actor
                # Actor should wait for tsumo.
                valid = !response
              else
                valid = !response || response.type == :hora
              end
            else
              raise("unknown action type: #{action.type}")
          end
        else
          valid = !response
        end
        raise("bad response %p for %p" % [response, action]) if !valid
      end
    end
    
    def doras
      return @dora_markers ? @dora_markers.map(){ |pai| pai.succ } : nil
    end
    
    def dump_action(action)
      puts(action.to_json())
      dump()
    end
    
    def dump()
      if @bakaze && @honba && @oya
        print("%s-%d kyoku %d honba  " % [@bakaze, @oya.id + 1, @honba])
      end
      print("pipai: %d  " % @pipais.size) if @pipais
      print("dora_marker: %s  " % @dora_markers.join(" ")) if @dora_markers
      puts()
      @players.each_with_index() do |player, i|
        if player.tehais
          puts("%s%s%d%s tehai: %s %s" %
               [player == @actor ? "*" : " ",
                player == @oya ? "{" : "[",
                i,
                player == @oya ? "}" : "]",
                Pai.dump_pais(player.tehais),
                player.furos.join(" ")])
          if player.reach_ho_index
            ho_str =
                Pai.dump_pais(player.ho[0...player.reach_ho_index]) + "=" +
                Pai.dump_pais(player.ho[player.reach_ho_index..-1])
          else
            ho_str = Pai.dump_pais(player.ho)
          end
          puts("     ho:    %s" % ho_str)
        end
      end
      puts("-" * 80)
      #gets()
    end
    
end


class ActiveBoard < Board
    
    def play_game()
      do_action(Action.new({:type => :start_game}))
      @next_oya = @players[0]
      while !self.game_finished?
        play_kyoku()
      end
      do_action(Action.new({:type => :end_game}))
    end
    
    def play_kyoku()
      $stderr.puts("play_kyoku")
      catch(:end_kyoku) do
        @pipais = @all_pais.shuffle()
        @pipais.shuffle!()
        @wanpais = @pipais.pop(14)
        dora_marker = @wanpais.pop()
        do_action(Action.new({:type => :start_kyoku, :oya => @next_oya, :dora_marker => dora_marker}))
        gets() # kari
        for player in @players
          do_action(Action.new(
              {:type => :haipai, :actor => player, :pais => @pipais.pop(13) }))
        end
        @actor = self.oya
        while !@pipais.empty?
          mota()
          @actor = @players[(@actor.id + 1) % 4]
        end
        process_ryukyoku()
      end
      do_action(Action.new({:type => :end_kyoku}))
    end
    
    # 摸打
    def mota()
      reach = false
      tsumo_actor = @actor
      actions = [Action.new({:type => :tsumo, :actor => @actor, :pai => @pipais.pop()})]
      while !actions.empty?
        if actions[0].type == :hora
          # actions.size >= 2 in case of double/triple ron
          process_hora(actions)
          throw(:end_kyoku)
        else
          raise("should not happen") if actions.size != 1
          action = actions[0]
          responses = do_action(action)
          case action.type
            when :daiminkan, :kakan, :ankan
              actions =
                [Action.new({:type => :tsumo, :actor => action.actor, :pai => @wanpais.pop()})]
              # TODO 王牌の補充、ドラの追加
              next
            when :reach
              reach = true
          end
          actions = choose_actions(responses)
          if reach && (actions.empty? || ![:dahai, :hora].include?(actions[0].type))
            do_action(Action.new({:type => :reach_accepted, :actor => tsumo_actor}))
          end
        end
      end
    end
    
    def choose_actions(actions)
      action = actions.find(){ |a| a }  # TODO fix this
      return action ? [action] : []
    end
    
    def process_hora(actions)
      # TODO ダブロンの上家取り
      for action in actions
        hora_type = action.actor == action.target ? :tsumo : :ron
        if hora_type == :tsumo
          tehais = action.actor.tehais[0...-1]
        else
          tehais = action.actor.tehais
        end
        hora = Hora.new({
          :tehais => tehais,
          :furos => action.actor.furos,
          :taken => action.pai,
          :hora_type => hora_type,
          :oya => action.actor == self.oya,
          :bakaze => self.bakaze,
          :jikaze => action.actor.jikaze,
          :doras => self.doras,
          :uradoras => [],  # TODO
          :reach => action.actor.reach?,
          :double_reach => false,  # TODO
          :ippatsu => false,  # TODO
          :rinshan => false,  # TODO
          :haitei => @pipais.empty?,
          :first_turn => false,  # TODO
          :chankan => false,  # TODO
        })
        raise("no yaku") if !hora.valid?
        #p [:hora, hora.fu, hora.fan, hora.points, hora.yakus]
        deltas = [0, 0, 0, 0]
        # TODO 積み棒
        deltas[action.actor.id] += hora.points + self.honba * 300
        deltas[action.actor.id] += self.players.select(){ |pl| pl.reach? }.size * 1000
        if hora_type == :tsumo
          for player in self.players
            next if player == action.actor
            deltas[player.id] -=
                ((player == self.oya ? hora.oya_payment : hora.ko_payment) + self.honba * 100)
          end
        else
          deltas[action.target.id] -= (hora.points + self.honba * 300)
        end
        for player in self.players
          player.points += deltas[player.id]
        end
        # TODO 役をフィールドに追加
        do_action(Action.new({
          :type => action.type,
          :actor => action.actor,
          :target => action.target,
          :pai => action.pai,
          :fu => hora.fu,
          :fan => hora.fan,
          :hora_points => hora.points,
          :deltas => deltas,
          :player_points => self.players.map(){ |pl| pl.points },
        }))
      end
      update_next_oya(actions.any?(){ |a| a.actor == self.oya })
    end
    
    def process_ryukyoku()
      tenpais = @players.map(){ |p| p.tenpai? }
      # TODO 点数計算
      do_action(Action.new({:type => :ryukyoku, :reason => :fanpai}))
      update_next_oya(tenpais[self.oya.id])
    end
    
    def update_next_oya(renchan)
      if renchan
        @next_oya = self.oya
      elsif self.bakaze == Pai.new("S") && self.oya == @players[3]
        # TODO Consider 西入、東風戦.
        @last = true
      else
        @next_oya = @players[(self.oya.id + 1) % 4]
      end
    end
    
    def game_finished?
      # TODO fix this
      if @last
        return true
      else
        @last = true if @game_type == :one_kyoku
        return false
      end
    end
    
    def num_pipais
      return @pipais.size
    end
    
end


class Archive < Board
    
    def initialize(path)
      super((0...4).map(){ PuppetPlayer.new() })
      case File.extname(path)
        when ".mjlog"
          @loader = TenhouMjlogLoader.new(path, self)
        else
          raise("unknown format")
      end
    end
    
    def play_game(&block)
      on_action(&block) if block
      @loader.play_game()
    end
    
end


class ShantenCounter
    
    # ryanpen = 両面 or 辺搭
    MENTSU_TYPES = [:kotsu, :shuntsu, :toitsu, :ryanpen, :kanta, :single]
    
    MENTSU_CATEGORIES = {
      :kotsu => :complete,
      :shuntsu => :complete,
      :toitsu => :toitsu,
      :ryanpen => :tatsu,
      :kanta => :tatsu,
      :single => :single,
    }
    
    MENTSU_SIZES = {
      :complete => 3,
      :toitsu => 2,
      :tatsu => 2,
      :single => 1,
    }
    
    def initialize(pais, max_shanten = nil, types = [:normal, :chitoitsu, :kokushimuso],
        num_used_pais = pais.size, need_all_combinations = true)
      
      @pais = pais
      @max_shanten = max_shanten
      @num_used_pais = num_used_pais
      @need_all_combinations = need_all_combinations
      raise(ArgumentError, "invalid number of pais") if @num_used_pais % 3 == 0
      @pai_set = Hash.new(0)
      for pai in @pais
        @pai_set[pai.remove_red()] += 1
      end
      
      @cache = {}
      results = []
      results.push(count_normal(@pai_set, [])) if types.include?(:normal)
      results.push(count_chitoi(@pai_set)) if types.include?(:chitoitsu)
      results.push(count_kokushi(@pai_set)) if types.include?(:kokushimuso)
      
      @shanten = 1.0/0.0
      @combinations = []
      for shanten, combinations in results
        next if @max_shanten && shanten > @max_shanten
        if shanten < @shanten
          @shanten = shanten
          @combinations = combinations
        elsif shanten == @shanten
          @combinations += combinations
        end
      end
      
    end
    
    attr_reader(:pais, :shanten, :combinations)
    
    def count_chitoi(pai_set)
      num_toitsus = pai_set.select(){ |pai, n| n >= 2 }.size
      num_singles = pai_set.select(){ |pai, n| n == 1 }.size
      if num_toitsus == 6 && num_singles == 0
        # toitsu * 5 + kotsu * 1 or toitsu * 5 + kantsu * 1
        shanten = 1
      else
        shanten = -1 + [7 - num_toitsus, 0].max
      end
      return [shanten, [:chitoitsu]]
    end
    
    def count_kokushi(pai_set)
      yaochus = pai_set.select(){ |pai, n| pai.yaochu? }
      has_yaochu_toitsu = yaochus.any?(){ |pai, n| n >= 2 }
      return [(13 - yaochus.size) - (has_yaochu_toitsu ? 1 : 0), [:kokushimuso]]
    end
    
    def count_normal(pai_set, mentsus)
      # TODO 上がり牌を全部自分が持っているケースを考慮
      key = get_key(pai_set, mentsus)
      if !@cache[key]
        if pai_set.empty?
          #p mentsus
          min_shanten = get_min_shanten_for_mentsus(mentsus)
          min_combinations = [mentsus]
        else
          shanten_lowerbound = get_min_shanten_for_mentsus(mentsus) if @max_shanten
          if @max_shanten && shanten_lowerbound > @max_shanten
            min_shanten = 1.0/0.0
            min_combinations = []
          else
            min_shanten = 1.0/0.0
            first_pai = pai_set.keys.sort()[0]
            for type in MENTSU_TYPES
              if @max_shanten == -1
                next if [:ryanpen, :kanta].include?(type)
                next if mentsus.any?(){ |t, ps| t == :toitsu } && type == :toitsu
              end
              (removed_pais, remains_set) = remove(pai_set, type, first_pai)
              if remains_set
                (shanten, combinations) =
                    count_normal(remains_set, mentsus + [[type, removed_pais]])
                if shanten < min_shanten
                  min_shanten = shanten
                  min_combinations = combinations
                  break if !@need_all_combinations && min_shanten == -1
                elsif shanten == min_shanten && shanten < 1.0/0.0
                  min_combinations += combinations
                end
              end
            end
          end
        end
        @cache[key] = [min_shanten, min_combinations]
      end
      return @cache[key]
    end
    
    def get_key(pai_set, mentsus)
      return [pai_set, mentsus.sort()]
    end
    
    def get_min_shanten_for_mentsus(mentsus)
      
      mentsu_categories = mentsus.map(){ |t, ps| MENTSU_CATEGORIES[t] }
      num_current_pais = mentsu_categories.map(){ |m| MENTSU_SIZES[m] }.inject(0, :+)
      num_remain_pais = @pais.size - num_current_pais
      
      min_shantens = []
      if index = mentsu_categories.index(:toitsu)
        # Assumes the 対子 is 雀頭.
        mentsu_categories.delete_at(index)
        min_shantens.push(get_min_shanten_without_janto(mentsu_categories, num_remain_pais))
      else
        # Assumes 雀頭 is missing.
        min_shantens.push(get_min_shanten_without_janto(mentsu_categories, num_remain_pais) + 1)
        if num_remain_pais >= 2
          # Assumes 雀頭 is in remaining pais.
          min_shantens.push(get_min_shanten_without_janto(mentsu_categories, num_remain_pais - 2))
        end
      end
      return min_shantens.min
      
    end
    
    def get_min_shanten_without_janto(mentsu_categories, num_remain_pais)
      
      # Assumes remaining pais generates best combinations.
      mentsu_categories += [:complete] * (num_remain_pais / 3)
      case num_remain_pais % 3
        when 1
          mentsu_categories.push(:single)
        when 2
          mentsu_categories.push(:toitsu)
      end
      
      sizes = mentsu_categories.map(){ |m| MENTSU_SIZES[m] }.sort_by(){ |n| -n }
      num_required_mentsus = @num_used_pais / 3
      return -1 + sizes[0...num_required_mentsus].inject(0){ |r, n| r + (3 - n) }
      
    end
    
    def remove(pai_set, type, first_pai)
      case type
        when :kotsu
          removed_pais = [first_pai] * 3
        when :shuntsu
          removed_pais = shuntsu_piece(first_pai, [0, 1, 2])
        when :toitsu
          removed_pais = [first_pai] * 2
        when :ryanpen
          removed_pais = shuntsu_piece(first_pai, [0, 1])
        when :kanta
          removed_pais = shuntsu_piece(first_pai, [0, 2])
        when :single
          removed_pais = [first_pai]
        else
          raise("should not happen")
      end
      return [nil, nil] if !removed_pais
      result_set = pai_set.dup()
      for pai in removed_pais
        if result_set[pai] > 0
          result_set[pai] -= 1
          result_set.delete(pai) if result_set[pai] == 0
        else
          return [nil, nil]
        end
      end
      return [removed_pais, result_set]
    end
    
    def shuntsu_piece(first_pai, relative_numbers)
      if first_pai.type == "t"
        return nil
      else
        return relative_numbers.map(){ |i| Pai.new(first_pai.type, first_pai.number + i) }
      end
    end
    
end


class TenpaiInfo
    
    ALL_YAOCHUS = Pai.parse_pais("19m19s19pESWNPFC")
    
    def initialize(pais)
      @pais = pais
      @shanten = ShantenCounter.new(@pais, 0)
    end
    
    def tenpai?
      return @shanten.shanten == 0
    end
    
    def waited_pais
      raise(ArgumentError, "invalid number of pais") if @pais.size % 3 != 1
      raise("not tenpai") if !self.tenpai?
      pai_set = Hash.new(0)
      for pai in @pais
        pai_set[pai.remove_red()] += 1
      end
      result = []
      for mentsus in @shanten.combinations
        case mentsus
          when :chitoitsu
            result.push(pai_set.find(){ |pai, n| n == 1 }[0])
          when :kokushimuso
            missing = ALL_YAOCHUS - pai_set.keys
            if missing.empty?
              result += ALL_YAOCHUS
            else
              result.push(missing[0])
            end
          else
            case mentsus.select(){ |t, ps| t == :toitsu }.size
              when 0  # 単騎
                (type, pais) = mentsus.find(){ |t, ps| t == :single }
                result.push(pais[0])
              when 1  # 両面、辺張、嵌張
                (type, pais) = mentsus.find(){ |t, ps| [:ryanpen, :kanta].include?(t) }
                relative_numbers = type == :ryanpen ? [-1, 2] : [1]
                result += relative_numbers.map(){ |r| pais[0].number + r }.
                    select(){ |n| (1..9).include?(n) }.
                    map(){ |n| Pai.new(pais[0].type, n) }
              when 2  # 双碰
                result += mentsus.select(){ |t, ps| t == :toitsu }.map(){ |t, ps| ps[0] }
              else
                raise("should not happen")
            end
        end
      end
      return result.sort().uniq()
    end
    
end


def shanten_counter_benchmark()
  all_pais = (["m", "p", "s"].map(){ |t| (1..9).map(){ |n| Pai.new(t, n) } }.flatten() +
      (1..7).map(){ |n| Pai.new("t", n) }) * 4
  start_time = Time.now.to_f
  100.times() do
    pais = all_pais.sample(14).sort()
    p pais.join(" ")
    shanten = ShantenCounter.count(pais)
    p shanten
=begin
    for i in 0...pais.size
      remains_pais = pais.dup()
      remains_pais.delete_at(i)
      if ShantenCounter.count(remains_pais) == shanten
        p pais[i]
      end
    end
=end
    #gets()
  end
  p Time.now.to_f - start_time
end


require "./hora"
