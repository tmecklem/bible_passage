module BiblePassage
  class ReferenceParser

    PASSAGE_REGEX = /^\s*(?<book_name>\d?\s*[A-Za-z\s]+)\s*(?<from_chapter>\d+)?:?(?<from_verse>\d+)?\s*-?\s*(?<to_chapter>\d+)?:?(?<to_verse>\d+)?\s*(?<child_reference>,.+)?/
    CHILD_PASSAGE_REGEX =                  /\s*(?<from_chapter>\d+)?:?(?<from_verse>\d+)?\s*(-?)\s*(?<to_chapter>\d+)?:?(?<to_verse>\d+)?\s*(?<child_reference>,.+)?$/

    def self.parse(passage, opts = {})
      ReferenceParser.new(opts).parse(passage)
    end

    attr_reader :options, :translator, :data_store, :raise_errors

    def initialize(opts = {})
      @options = opts
      @raise_errors = opts.fetch(:raise_errors, true)
      @translator = options.delete(:translator) || BookKeyTranslator.new
      @data_store = options[:data_store] ||= BookDataStore.new
    end

    # The main method used for parsing passage strings
    def parse(passage)
      match = passage.match(PASSAGE_REGEX)
      return handle_invalid_reference("#{passage} is not a valid reference") if match.nil?

      book_key = translator.keyify(match[:book_name], raise_errors)
      return InvalidReference.new("#{match[:book_name]} is not a valid book") if book_key.nil?

      ref = process_match(book_key, match)
      ref.child = parse_child(match[:child_reference].gsub(/^,\s*/, ''), ref) if match[:child_reference]
      ref
    end

    private

    ##
    # Parses a child reference in a compound passage string
    def parse_child(passage, parent)
      if passage.match(PASSAGE_REGEX)
        ref = parse(passage)
      else
        match = passage.match(CHILD_PASSAGE_REGEX)
        book_key = parent.book_key
        attrs = parent.inheritable_attributes
        if attrs[:from_chapter]
          if match[2]
            attrs[:from_chapter] = match[:from_chapter].to_i
            attrs[:from_verse] = match[:from_verse].to_i
          else
            attrs[:from_verse] = match[:from_chapter].to_i
          end
        else
          attrs[:from_chapter] = match[:from_chapter].to_i
          if match[:from_verse]
            attrs[:from_verse] = match[:from_verse].to_i
          end
        end
        if match[:to_verse]
          attrs[:to_chapter] = int_param(match[:to_chapter])
          attrs[:to_verse] = int_param(match[:to_verse])
        elsif attrs[:from_verse]
          attrs[:to_verse] = int_param(match[:to_chapter])
        else
          attrs[:to_chapter] = int_param(match[:to_chapter])
        end
        ref = Reference.new(book_key, attrs[:from_chapter], attrs[:from_verse],
                  attrs[:to_chapter], attrs[:to_verse])
      end
      ref.parent = parent
      ref.child = parse_child(match[:child_reference].gsub(/^,\s*/, ''), ref) if match && match[:child_reference]
      ref
    end

    def int_param(param)
      param ? param.to_i : nil
    end

    def process_match(book_key, match)
      if data_store.number_of_chapters(book_key) == 1
        process_single_chapter_match(book_key, match)
      else
        process_multi_chapter_match(book_key, match)
      end
    end

    def process_multi_chapter_match(book_key, match)
      if match[:from_chapter]
        from_chapter = match[:from_chapter].to_i
        # has from verse
        if match[:from_verse]
          from_verse = match[:from_verse].to_i
          if match[:to_verse]
            to_chapter = match[:to_chapter].to_i
            to_verse = match[:to_verse].to_i
          else
            # there is no chapter, so verse is stored in :to_chapter match
            to_verse = int_param(match[:to_chapter])
          end
        else
          from_verse = int_param(match[:from_verse])
          to_chapter = int_param(match[:to_chapter])
        end
      end
      Reference.new(book_key, from_chapter, from_verse, to_chapter, to_verse, options)
    end

    # In single chapter books, the from/to chapter matches
    # actually represent the from/to verses
    # TODO: maybe there's a better way to represent that mismatch in code
    def process_single_chapter_match(book_key, match)
      if match[:from_chapter]
        from_verse = match[:from_chapter].to_i
        to_verse = match[:to_chapter].to_i if match[:to_chapter]
      end
      if match[0] =~ /:/
        book_name = data_store.book_name(book_key)
        msg = "#{book_name} doesn't have any chapters"
        return handle_invalid_reference(msg)
      end
      Reference.new(book_key, nil, from_verse, nil, to_verse, options)
    end

    def handle_invalid_reference(message)
      return InvalidReference.new(message) unless raise_errors
      raise InvalidReferenceError.new(message)
    end
  end
end
