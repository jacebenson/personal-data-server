require 'test_helper'

class Entertainment::GoodreadsDataProcessorTest < ActiveSupport::TestCase
  setup do
    @user = users(:user_one)
    @temp_file = Tempfile.new(['goodreads_test', '.csv'])
  end

  teardown do
    @temp_file.close
    @temp_file.unlink
  end

  test "processes valid goodreads CSV data" do
    csv_data = <<~CSV
      Book Id,Title,Author,Author l-f,Additional Authors,ISBN,ISBN13,My Rating,Average Rating,Publisher,Binding,Number of Pages,Year Published,Original Publication Year,Date Read,Date Added,Bookshelves,Bookshelves with positions,Exclusive Shelf,My Review,Spoiler,Private Notes,Read Count,Recommended For,Recommended By,Owned Copies,Original Purchase Date,Original Purchase Location,Condition,Condition Description,BCID
      12345,Test Book,Test Author,"Author, Test",,1234567890,9781234567890,5,4.2,Test Publisher,Paperback,300,2023,2023,2023/12/01,2023/01/01,"read (#1)","read (#1)",read,,,,1,,,0,,,,,
    CSV

    @temp_file.write(csv_data)
    @temp_file.rewind

    processor = Entertainment::GoodreadsDataProcessor.new(@temp_file.path, @user)
    result = processor.process

    assert result, "Processing should succeed"
    assert_equal 1, processor.processed_count
    assert_equal 0, processor.skipped_count
    assert_empty processor.errors

    # Verify the book was created
    book = @user.entertainment_contents.goodreads.first
    assert book
    assert_equal "Test Book", book.title
    assert_equal "Test Author", book.author
    assert_equal 5, book.my_rating
    assert_equal "read", book.exclusive_shelf
    assert_equal Date.parse("2023-12-01"), book.date_read
  end

  test "handles invalid CSV gracefully" do
    @temp_file.write("invalid,csv,data")
    @temp_file.rewind

    processor = Entertainment::GoodreadsDataProcessor.new(@temp_file.path, @user)
    result = processor.process

    assert_not result, "Processing should fail for invalid CSV"
    assert_not_empty processor.errors
  end

  test "skips duplicate books" do
    # Create existing book
    @user.entertainment_contents.create!(
      content_type: 'goodreads',
      title: 'Test Book',
      author: 'Test Author',
      exclusive_shelf: 'read',
      date_consumed: Time.current,
      source: 'goodreads'
    )

    csv_data = <<~CSV
      Book Id,Title,Author,Exclusive Shelf
      12345,Test Book,Test Author,read
    CSV

    @temp_file.write(csv_data)
    @temp_file.rewind

    processor = Entertainment::GoodreadsDataProcessor.new(@temp_file.path, @user)
    result = processor.process

    assert result, "Processing should succeed"
    assert_equal 0, processor.processed_count
    assert_equal 1, processor.skipped_count
  end

  test "validates headers correctly" do
    csv_data = <<~CSV
      Title,Author,Exclusive Shelf
      Test Book,Test Author,read
    CSV

    @temp_file.write(csv_data)
    @temp_file.rewind

    validation = Entertainment::GoodreadsDataProcessor.validate_headers(@temp_file.path)

    assert validation[:valid], "Should be valid with required headers"
    assert_empty validation[:missing_headers]
    assert_includes validation[:found_headers], 'Title'
    assert_includes validation[:found_headers], 'Author'
    assert_includes validation[:found_headers], 'Exclusive Shelf'
  end
end
