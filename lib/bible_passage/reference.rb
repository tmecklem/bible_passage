module BiblePassage

  class Reference

    attr_accessor :child
    attr_reader :error, :book_key, :book
    attr_writer :parent

    def self.parse(passage, options = {})
      ReferenceParser.parse(passage, options)
    end

    def initialize(book_key, from_chapter = nil, from_verse = nil,
                   to_chapter = nil, to_verse = nil, options = {})
      @raise_errors = options.has_key?(:raise_errors) ? options[:raise_errors] : true
      @data_store = options[:data_store] || BookDataStore.new
      self.book_key = book_key
      self.from_chapter = int_param(from_chapter)
      self.from_verse = int_param(from_verse)
      self.to_chapter = calculate_to_chapter(to_chapter)
      self.to_verse = calculate_to_verse(to_verse)
    end

    def book_key=(key)
      @book = @data_store.book_name(key)
      @book_key = key
    end

    def from_chapter
      @from_chapter || 1
    end

    def from_chapter=(val)
      if val
        if val < 1 || val > @data_store.number_of_chapters(book_key)
          @error = "#{book} doesn't have a chapter #{val}"
          raise InvalidReferenceError.new(@error) if @raise_errors
        end
        @inherit_book_key = true
        @from_chapter = val
      end
    end

    def from_verse
      @from_verse || 1
    end

    def from_verse=(val)
      if val && valid?
        if val > @data_store.number_of_verses(book_key, from_chapter) || val < 1
          @error = "#{book} #{from_chapter} doesn't have a verse #{val}"
          raise InvalidReferenceError.new(@error) if @raise_errors
        end
        @inherit_chapter = true
        @from_verse = val
      end
    end

    def to_chapter
      @to_chapter || from_chapter
    end

    def to_chapter=(val)
      if val
        if val < from_chapter
          @error = "to_chapter cannot be before from_chapter"
          raise InvalidReferenceError.new(@error) if @raise_errors
        end
        if val > @data_store.number_of_chapters(book_key)
          @error = "#{book} doesn't have a chapter #{val}"
          raise InvalidReferenceError.new(@error) if @raise_errors
        end
        @to_chapter = val
      end
    end

    def to_verse
      @to_verse || from_verse
    end

    def to_verse=(val)
      if val && valid?
        if val < from_verse && single_chapter_passage?
          @error = "to_verse cannot be before from_verse"
          raise InvalidReferenceError.new(@error) if @raise_errors
        end
        if val > @data_store.number_of_verses(book_key, to_chapter)
          @error = "#{book} #{to_chapter} doesn't have a verse #{val}"
          raise InvalidReferenceError.new(@error) if @raise_errors
        end
        @to_verse = val
      end
    end

    def to_s
      return nil if !valid?
      if @parent
        out = to_s_child
      else
        out = to_s_root
      end
      out << child.to_s if child
      out
    end

    def whole_chapters?
      from_verse == 1 && to_verse_last_in_chapter?
    end

    def whole_book?
      from_chapter == 1 && from_verse == 1 && 
        to_chapter == @data_store.number_of_chapters(book_key) &&
        to_verse == @data_store.number_of_verses(book_key, to_chapter)
    end

    def whole_chapter?
      whole_chapters? && from_chapter == to_chapter
    end

    def attributes
      %w{book_key from_chapter from_verse to_chapter to_verse}.
        inject({}) do |memo, attr_key|
          memo.merge(attr_key.to_sym => send(attr_key))
      end
    end

    def ==(other)
      attributes == other.attributes
    end

    def inheritable_attributes
      out = {}
      out[:book_key] = book_key if @inherit_book_key
      out[:from_chapter] = to_chapter if @inherit_chapter
      out
    end

    def valid?
      @error.nil?
    end

    private
    def from_part
      out = ''
      unless whole_book?
        out << ' '
        out << from_chapter.to_s
        out << from_verse_part
      end
      out
    end

    def from_verse_part
      if whole_chapters?
        ''
      else
        out = single_chapter_book? ? ' ' : ':'
        "#{out}#{from_verse.to_s}"
      end
    end

    def to_part
      out = ''
      unless whole_book? || single_verse_passage? || whole_chapter?
        out << '-'
        unless single_chapter_passage?
          out << to_chapter_part 
        end
        out << to_verse_part
      end
      out
    end

    def to_chapter_part
      if single_chapter_passage?
        ''
      else
        to_chapter.to_s
      end
    end

    def to_verse_part
      if single_verse_passage? || whole_chapters?
        ''
      else
        out = ''
        out << '-' if single_chapter_book?
        out << ':' unless single_chapter_passage?
        out << to_verse.to_s
        out
      end
    end

    def int_param(param)
      param ? param.to_i : nil
    end

    def single_chapter_passage?
      from_chapter == to_chapter
    end

    def single_verse_passage?
      single_chapter_passage? && from_verse == to_verse
    end

    def single_chapter_book?
      @data_store.number_of_chapters(book_key) == 1
    end

    def to_verse_last_in_chapter?
      to_verse == @data_store.number_of_verses(book_key, to_chapter)
    end

    def calculate_to_chapter(supplied_to_chapter)
      int_param(supplied_to_chapter) || begin
        if @from_chapter
          @from_chapter
        else
          @data_store.number_of_chapters(book_key)
        end
      end
    end

    def calculate_to_verse(supplied_to_verse)
      int_param(supplied_to_verse) ||
        @from_verse ||
          @data_store.number_of_verses(book_key, self.to_chapter)
    end

    def to_s_root
      if single_chapter_book?
        out = "#{book}#{from_verse_part}#{to_verse_part}"
      else
        out = "#{book}#{from_part}#{to_part}"
      end
    end

    def to_s_child
      out = ','
      if book_key != @parent.book_key
        out << " #{to_s_root}"
      else
        out << "#{from_part}#{to_part}"
      end
    end

  end

end
