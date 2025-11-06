# Bible App - Supabase Integration

This is a SwiftUI Bible app integrated with Supabase for data storage and management.

> **Note:** This is a verification test to confirm repo access and PR workflow.

## Setup Instructions

### 1. Install Dependencies
Make sure you have the Supabase Swift SDK installed. The project uses Swift Package Manager with the following dependency:
- Supabase Swift SDK (v2.0.0+)

### 2. Database Setup
You'll need to create the following tables in your Supabase database:

#### Books Table
```sql
CREATE TABLE books (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    abbreviation TEXT NOT NULL,
    testament TEXT NOT NULL, -- 'Old' or 'New'
    chapters INTEGER NOT NULL
);
```

#### Verses Table
```sql
CREATE TABLE verses (
    id SERIAL PRIMARY KEY,
    book_id INTEGER REFERENCES books(id),
    chapter INTEGER NOT NULL,
    verse INTEGER NOT NULL,
    text TEXT NOT NULL,
    version TEXT NOT NULL DEFAULT 'KJV'
);
```

### 3. Sample Data
You can populate the books table with the 66 books of the Bible:

```sql
-- Insert Old Testament books
INSERT INTO books (name, abbreviation, testament, chapters) VALUES
('Genesis', 'Gen', 'Old', 50),
('Exodus', 'Ex', 'Old', 40),
('Leviticus', 'Lev', 'Old', 27),
-- ... continue with all 39 Old Testament books

-- Insert New Testament books
INSERT INTO books (name, abbreviation, testament, chapters) VALUES
('Matthew', 'Matt', 'New', 28),
('Mark', 'Mark', 'New', 16),
('Luke', 'Luke', 'New', 24),
-- ... continue with all 27 New Testament books
```

### 4. Enable Row Level Security (Optional)
For production apps, consider enabling RLS and creating appropriate policies:

```sql
-- Enable RLS
ALTER TABLE books ENABLE ROW LEVEL SECURITY;
ALTER TABLE verses ENABLE ROW LEVEL SECURITY;

-- Allow public read access
CREATE POLICY "Public read access for books" ON books FOR SELECT USING (true);
CREATE POLICY "Public read access for verses" ON verses FOR SELECT USING (true);
```

## Features

- ✅ Supabase integration
- 🔍 Bible verse search functionality
- 📚 Book and chapter navigation
- 🧷 Bookmarks and notes (local)
- 📱 SwiftUI interface

## Usage

1. Open the project in Xcode
2. Build and run the app
3. The app will automatically test the Supabase connection
4. If connected successfully, you can start fetching Bible content

## API Methods Available

- `BibleService.shared.fetchBooks()` - Get all Bible books
- `BibleService.shared.fetchVerses(bookId:chapter:)` - Get verses from specific book/chapter
- `BibleService.shared.searchVerses(query:)` - Search for verses containing text
- `BibleService.shared.testConnection()` - Test Supabase connection

## Next Steps

1. Add Bible verse data to your Supabase database
2. Implement user authentication if needed
3. Add offline caching capabilities
4. Create a more sophisticated UI for browsing verses
5. Add features like bookmarks, notes, and reading plans
