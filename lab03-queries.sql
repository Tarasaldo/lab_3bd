-- =====================================================================
-- Лабораторна робота 3. Модифікація даних та транзакції
-- Самойло Тарас, ІПЗ-32. PostgreSQL (Supabase)
-- Кожен блок "-- [N-M]" виконувався окремим запуском у SQL Editor.
-- =====================================================================

-- #####################################################################
-- РІВЕНЬ 1
-- #####################################################################

-- [1-1] Структура БД з обмеженнями цілісності
CREATE TABLE authors (
    author_id  SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name  VARCHAR(50) NOT NULL,
    birth_year INTEGER CHECK (birth_year >= 1000 AND birth_year <= EXTRACT(YEAR FROM CURRENT_DATE)),
    country    VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE books (
    book_id          SERIAL PRIMARY KEY,
    isbn             VARCHAR(17) UNIQUE NOT NULL,
    title            VARCHAR(200) NOT NULL,
    author_id        INTEGER NOT NULL,
    publication_year INTEGER CHECK (publication_year >= 1450),
    genre            VARCHAR(50),
    total_copies     INTEGER DEFAULT 1 CHECK (total_copies >= 0),
    available_copies INTEGER DEFAULT 1 CHECK (available_copies >= 0),
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (author_id) REFERENCES authors(author_id) ON DELETE RESTRICT,
    CHECK (available_copies <= total_copies)
);

CREATE TABLE readers (
    reader_id           SERIAL PRIMARY KEY,
    first_name          VARCHAR(50) NOT NULL,
    last_name           VARCHAR(50) NOT NULL,
    email               VARCHAR(100) UNIQUE NOT NULL,
    phone               VARCHAR(20),
    library_card_number VARCHAR(20) UNIQUE NOT NULL,
    registration_date   DATE DEFAULT CURRENT_DATE,
    status              VARCHAR(20) DEFAULT 'Active' CHECK (status IN ('Active', 'Blocked', 'Inactive'))
);

CREATE TABLE lendings (
    lending_id   SERIAL PRIMARY KEY,
    book_id      INTEGER NOT NULL,
    reader_id    INTEGER NOT NULL,
    lending_date DATE DEFAULT CURRENT_DATE,
    due_date     DATE NOT NULL,
    return_date  DATE,
    FOREIGN KEY (book_id)   REFERENCES books(book_id)     ON DELETE RESTRICT,
    FOREIGN KEY (reader_id) REFERENCES readers(reader_id) ON DELETE RESTRICT,
    CHECK (due_date > lending_date),
    CHECK (return_date IS NULL OR return_date >= lending_date)
);

-- Supabase за замовчуванням відкриває нові таблиці public для API-ролей
REVOKE ALL ON authors, books, readers, lendings FROM anon, authenticated;

SELECT tc.table_name, tc.constraint_type, tc.constraint_name
FROM information_schema.table_constraints tc
WHERE tc.table_name IN ('authors','books','readers','lendings')
  AND tc.constraint_type <> 'NOT NULL' AND tc.constraint_name NOT LIKE '%not_null'
ORDER BY tc.table_name, tc.constraint_type;

-- [1-2] Початкові дані
INSERT INTO authors (first_name, last_name, birth_year, country) VALUES
    ('Тарас', 'Шевченко', 1814, 'Україна'),
    ('Іван', 'Франко', 1856, 'Україна'),
    ('Леся', 'Українка', 1871, 'Україна'),
    ('Михайло', 'Коцюбинський', 1864, 'Україна'),
    ('Панас', 'Мирний', 1849, 'Україна');

INSERT INTO books (isbn, title, author_id, publication_year, genre, total_copies, available_copies) VALUES
    ('978-966-03-4561-2', 'Кобзар', 1, 1840, 'Поезія', 10, 8),
    ('978-966-03-4562-9', 'Захар Беркут', 2, 1883, 'Історична проза', 5, 4),
    ('978-966-03-4563-6', 'Лісова пісня', 3, 1911, 'Драма', 7, 7),
    ('978-966-03-4564-3', 'Тіні забутих предків', 4, 1911, 'Повість', 6, 5),
    ('978-966-03-4565-0', 'Хіба ревуть воли, як ясла повні', 5, 1880, 'Повість', 4, 4);

INSERT INTO readers (first_name, last_name, email, phone, library_card_number) VALUES
    ('Олена', 'Петренко', 'olena.petrenko@email.com', '+380501234567', 'LIB-2024-001'),
    ('Андрій', 'Коваленко', 'andrii.kovalenko@email.com', '+380502345678', 'LIB-2024-002'),
    ('Марія', 'Сидоренко', 'maria.sydorenko@email.com', '+380503456789', 'LIB-2024-003'),
    ('Іван', 'Мельник', 'ivan.melnyk@email.com', '+380504567890', 'LIB-2024-004');

-- INSERT ... SELECT: неактивний читач і видачі на основі запиту
INSERT INTO readers (first_name, last_name, email, library_card_number, status)
VALUES ('Петро', 'Неактивний', 'petro.old@email.com', 'LIB-2020-099', 'Inactive');

INSERT INTO lendings (book_id, reader_id, lending_date, due_date)
SELECT b.book_id, r.reader_id, CURRENT_DATE - 20, CURRENT_DATE - 6
FROM books b CROSS JOIN readers r
WHERE b.title = 'Захар Беркут' AND r.library_card_number = 'LIB-2024-002';

SELECT 'authors' AS tbl, COUNT(*) FROM authors UNION ALL
SELECT 'books', COUNT(*) FROM books UNION ALL
SELECT 'readers', COUNT(*) FROM readers UNION ALL
SELECT 'lendings', COUNT(*) FROM lendings;

-- [1-3a] Перевірка обмежень (кожен INSERT окремим запуском, усі мають впасти): UNIQUE
INSERT INTO books (isbn, title, author_id, publication_year)
VALUES ('978-966-03-4561-2', 'Дублікат ISBN', 1, 2000);

-- [1-3b] FOREIGN KEY
INSERT INTO books (isbn, title, author_id, publication_year)
VALUES ('978-000-00-0000-1', 'Без автора', 999, 2000);

-- [1-3c] CHECK (available_copies <= total_copies)
INSERT INTO books (isbn, title, author_id, total_copies, available_copies)
VALUES ('978-000-00-0000-2', 'Забагато', 1, 2, 5);

-- [1-3d] NOT NULL
INSERT INTO readers (first_name, last_name, email, library_card_number, status)
VALUES ('Тест', NULL, 't@e.com', 'LIB-X', 'Active');

-- [1-4] Безпечне оновлення: SELECT -> UPDATE ... RETURNING -> SELECT
SELECT book_id, title, available_copies FROM books WHERE book_id = 1;

UPDATE books
SET available_copies = available_copies - 1
WHERE book_id = 1 AND available_copies > 0
RETURNING book_id, title, available_copies;

-- оновлення з підзапитом
UPDATE books
SET genre = 'Класична поезія'
WHERE author_id IN (SELECT author_id FROM authors WHERE birth_year < 1850)
  AND genre = 'Поезія'
RETURNING book_id, title, genre;

-- [1-5] Транзакція видачі книги
BEGIN;
INSERT INTO lendings (book_id, reader_id, due_date)
VALUES (1, 1, CURRENT_DATE + 14);

UPDATE books
SET available_copies = available_copies - 1
WHERE book_id = 1 AND available_copies > 0;
COMMIT;

SELECT l.lending_id, b.title, r.last_name, l.lending_date, l.due_date, b.available_copies
FROM lendings l JOIN books b USING (book_id) JOIN readers r USING (reader_id)
ORDER BY l.lending_id;

-- [1-6] ROLLBACK при помилці: перша операція виконалась, друга порушила FK
BEGIN;
UPDATE authors SET country = 'ЗМІНЕНО' WHERE author_id = 1;
DELETE FROM authors WHERE author_id = 1;   -- ERROR: violates foreign key constraint
COMMIT;

-- [1-7] Перевірка: UPDATE з тієї ж транзакції не зберігся
SELECT author_id, first_name, last_name, country FROM authors WHERE author_id = 1;

-- [1-8] Явний ROLLBACK (зміна рішення)
BEGIN;
DELETE FROM lendings WHERE return_date IS NULL;
SELECT COUNT(*) AS inside_tx FROM lendings;
ROLLBACK;
SELECT COUNT(*) AS after_rollback FROM lendings;

-- [1-9] Безпечне видалення
SELECT * FROM readers
WHERE status = 'Inactive'
  AND reader_id NOT IN (SELECT reader_id FROM lendings WHERE return_date IS NULL);

DELETE FROM readers
WHERE status = 'Inactive'
  AND reader_id NOT IN (SELECT reader_id FROM lendings WHERE return_date IS NULL)
RETURNING reader_id, first_name, last_name, status;

-- [1-10] Видалення читача з активною видачею блокується FK (RESTRICT)
DELETE FROM readers WHERE reader_id = 2;

-- #####################################################################
-- РІВЕНЬ 2
-- #####################################################################

-- [2-1] Нові таблиці + каскадні зв'язки всіх типів
CREATE TABLE reservations (
    reservation_id   SERIAL PRIMARY KEY,
    book_id          INTEGER NOT NULL,
    reader_id        INTEGER NOT NULL,
    reservation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expiration_date  TIMESTAMP NOT NULL,
    status           VARCHAR(20) DEFAULT 'Active' CHECK (status IN ('Active', 'Fulfilled', 'Cancelled', 'Expired')),
    FOREIGN KEY (book_id)   REFERENCES books(book_id)     ON DELETE CASCADE,
    FOREIGN KEY (reader_id) REFERENCES readers(reader_id) ON DELETE CASCADE
);

CREATE TABLE audit_log (
    log_id     SERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    operation  VARCHAR(10) NOT NULL,
    record_id  INTEGER NOT NULL,
    old_data   JSONB,
    new_data   JSONB,
    changed_at TIMESTAMP DEFAULT clock_timestamp(),
    changed_by VARCHAR(100) DEFAULT CURRENT_USER
);

-- видавництва (ON DELETE SET NULL) і категорії (ON DELETE SET DEFAULT)
CREATE TABLE publishers (
    publisher_id SERIAL PRIMARY KEY,
    name         VARCHAR(100) UNIQUE NOT NULL
);
CREATE TABLE book_categories (
    category_id INTEGER PRIMARY KEY,
    name        VARCHAR(50) UNIQUE NOT NULL
);
INSERT INTO book_categories VALUES (1, 'Загальна'), (2, 'Шкільна програма'), (3, 'Рідкісні видання');
INSERT INTO publishers (name) VALUES ('Знання'), ('А-БА-БА-ГА-ЛА-МА-ГА'), ('Фоліо');

ALTER TABLE books
    ADD COLUMN publisher_id INTEGER REFERENCES publishers(publisher_id) ON DELETE SET NULL,
    ADD COLUMN category_id  INTEGER DEFAULT 1 REFERENCES book_categories(category_id) ON DELETE SET DEFAULT;

-- ON UPDATE CASCADE: номер читацького квитка як природний ключ у бронюваннях
ALTER TABLE reservations
    ADD COLUMN card_number VARCHAR(20) REFERENCES readers(library_card_number) ON UPDATE CASCADE;

UPDATE books SET publisher_id = 1, category_id = 2 WHERE book_id IN (1, 2, 3);
UPDATE books SET publisher_id = 3, category_id = 3 WHERE book_id IN (4, 5);

REVOKE ALL ON reservations, audit_log, publishers, book_categories FROM anon, authenticated;

SELECT conrelid::regclass AS child_table, conname,
       confrelid::regclass AS parent_table,
       CASE confdeltype WHEN 'a' THEN 'NO ACTION' WHEN 'r' THEN 'RESTRICT' WHEN 'c' THEN 'CASCADE'
                        WHEN 'n' THEN 'SET NULL' WHEN 'd' THEN 'SET DEFAULT' END AS on_delete,
       CASE confupdtype WHEN 'a' THEN 'NO ACTION' WHEN 'r' THEN 'RESTRICT' WHEN 'c' THEN 'CASCADE'
                        WHEN 'n' THEN 'SET NULL' WHEN 'd' THEN 'SET DEFAULT' END AS on_update
FROM pg_constraint
WHERE contype = 'f'
  AND conrelid::regclass::text IN ('books','lendings','reservations')
ORDER BY 1, 2;

-- [2-2] Тригер аудиту (універсальна функція для кількох таблиць)
CREATE OR REPLACE FUNCTION log_changes()
RETURNS TRIGGER AS $$
DECLARE
    v_pk TEXT := TG_ARGV[0];   -- назва стовпця первинного ключа
BEGIN
    IF current_setting('app.restoring', true) = 'on' THEN
        RETURN NULL;           -- під час відновлення з бекапу не логуємо
    END IF;
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (table_name, operation, record_id, new_data)
        VALUES (TG_TABLE_NAME, 'INSERT', (to_jsonb(NEW)->>v_pk)::int, to_jsonb(NEW));
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (table_name, operation, record_id, old_data, new_data)
        VALUES (TG_TABLE_NAME, 'UPDATE', (to_jsonb(NEW)->>v_pk)::int, to_jsonb(OLD), to_jsonb(NEW));
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (table_name, operation, record_id, old_data)
        VALUES (TG_TABLE_NAME, 'DELETE', (to_jsonb(OLD)->>v_pk)::int, to_jsonb(OLD));
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER books_audit_trigger AFTER INSERT OR UPDATE OR DELETE ON books
    FOR EACH ROW EXECUTE FUNCTION log_changes('book_id');
CREATE TRIGGER readers_audit_trigger AFTER INSERT OR UPDATE OR DELETE ON readers
    FOR EACH ROW EXECUTE FUNCTION log_changes('reader_id');
CREATE TRIGGER lendings_audit_trigger AFTER INSERT OR UPDATE OR DELETE ON lendings
    FOR EACH ROW EXECUTE FUNCTION log_changes('lending_id');
CREATE TRIGGER reservations_audit_trigger AFTER INSERT OR UPDATE OR DELETE ON reservations
    FOR EACH ROW EXECUTE FUNCTION log_changes('reservation_id');

UPDATE books SET available_copies = available_copies + 1 WHERE book_id = 1;

SELECT log_id, table_name, operation, record_id,
       new_data->>'title' AS title,
       old_data->>'available_copies' AS old_copies,
       new_data->>'available_copies' AS new_copies,
       changed_at, changed_by
FROM audit_log ORDER BY log_id DESC;

-- [2-3] Бронювання (тестові дані)
INSERT INTO reservations (book_id, reader_id, card_number, reservation_date, expiration_date)
SELECT 2, r.reader_id, r.library_card_number, now() - (r.reader_id || ' hours')::interval, now() + INTERVAL '7 days'
FROM readers r WHERE r.reader_id IN (3, 4);

SELECT * FROM reservations ORDER BY reservation_id;

-- [2-4] Складна транзакція: повернення книги + видача наступному у черзі бронювань
BEGIN;
-- 1) закриваємо видачу
UPDATE lendings SET return_date = CURRENT_DATE
WHERE lending_id = 1 AND return_date IS NULL;
-- 2) повертаємо примірник
UPDATE books SET available_copies = available_copies + 1
WHERE book_id = (SELECT book_id FROM lendings WHERE lending_id = 1);
-- 3) найстаріше активне бронювання цієї книги -> Fulfilled
WITH next_res AS (
    SELECT reservation_id, reader_id, book_id
    FROM reservations
    WHERE book_id = (SELECT book_id FROM lendings WHERE lending_id = 1) AND status = 'Active'
    ORDER BY reservation_date
    LIMIT 1
    FOR UPDATE
), upd AS (
    UPDATE reservations r SET status = 'Fulfilled'
    FROM next_res n WHERE r.reservation_id = n.reservation_id
    RETURNING r.reader_id, r.book_id
)
-- 4) одразу видаємо книгу цьому читачеві
INSERT INTO lendings (book_id, reader_id, due_date)
SELECT book_id, reader_id, CURRENT_DATE + 14 FROM upd;
-- 5) і знову зменшуємо доступні примірники
UPDATE books SET available_copies = available_copies - 1
WHERE book_id = (SELECT book_id FROM lendings WHERE lending_id = 1);
COMMIT;

SELECT 'lending' AS what, lending_id AS id, book_id, reader_id, return_date::text AS info FROM lendings
UNION ALL
SELECT 'reservation', reservation_id, book_id, reader_id, status FROM reservations
UNION ALL
SELECT 'book', book_id, book_id, NULL, 'available=' || available_copies FROM books WHERE book_id = 2
ORDER BY 1, 2;

-- [2-5] SAVEPOINT: частковий відкат (без помилки)
BEGIN;
INSERT INTO authors (first_name, last_name, birth_year, country)
VALUES ('Ольга', 'Кобилянська', 1863, 'Україна');
SAVEPOINT after_author;

INSERT INTO books (isbn, title, author_id, publication_year, genre, total_copies, available_copies)
VALUES ('978-966-03-4566-7', 'Земля (помилкова назва)',
        (SELECT author_id FROM authors WHERE last_name = 'Кобилянська'), 1902, 'Роман', 3, 3);
SAVEPOINT after_book;

UPDATE books SET available_copies = 0 WHERE isbn = '978-966-03-4566-7';

ROLLBACK TO SAVEPOINT after_author;   -- скасовує книгу і UPDATE, автор лишається

INSERT INTO books (isbn, title, author_id, publication_year, genre, total_copies, available_copies)
VALUES ('978-966-03-4567-4', 'Земля',
        (SELECT author_id FROM authors WHERE last_name = 'Кобилянська'), 1902, 'Роман', 3, 3);
COMMIT;

SELECT a.last_name, b.isbn, b.title, b.available_copies
FROM authors a LEFT JOIN books b USING (author_id)
WHERE a.last_name = 'Кобилянська';

-- [2-6] SAVEPOINT при помилці: PL/pgSQL-блок EXCEPTION = неявний SAVEPOINT
DO $$
BEGIN
    INSERT INTO authors (first_name, last_name, birth_year, country)
    VALUES ('Василь', 'Стефаник', 1871, 'Україна');
    BEGIN   -- тут PostgreSQL ставить SAVEPOINT
        INSERT INTO books (isbn, title, author_id, publication_year, genre)
        VALUES ('978-966-03-4567-4', 'Дублікат ISBN',
                (SELECT author_id FROM authors WHERE last_name = 'Стефаник'), 1900, 'Новели');
    EXCEPTION WHEN unique_violation THEN   -- ROLLBACK TO SAVEPOINT
        RAISE NOTICE 'Дублікат ISBN відкочено: %', SQLERRM;
        INSERT INTO books (isbn, title, author_id, publication_year, genre, total_copies, available_copies)
        VALUES ('978-966-03-4568-1', 'Камінний хрест',
                (SELECT author_id FROM authors WHERE last_name = 'Стефаник'), 1900, 'Новели', 2, 2);
    END;
END $$;

SELECT a.last_name, b.isbn, b.title FROM authors a JOIN books b USING (author_id)
WHERE a.last_name = 'Стефаник';

-- [2-7] Каскадні операції
INSERT INTO authors (first_name, last_name, birth_year, country)
VALUES ('Тестовий', 'Автор', 1900, 'Україна');
INSERT INTO books (isbn, title, author_id, publication_year, genre, total_copies, available_copies, publisher_id, category_id)
VALUES ('978-966-00-0000-0', 'Тестова книга',
        (SELECT author_id FROM authors WHERE last_name = 'Автор'), 2000, 'Тест', 1, 0, 2, 3);
INSERT INTO reservations (book_id, reader_id, card_number, expiration_date)
SELECT (SELECT book_id FROM books WHERE isbn = '978-966-00-0000-0'), reader_id, library_card_number, now() + INTERVAL '7 days'
FROM readers WHERE reader_id IN (1, 3);

SELECT b.book_id, b.title, b.publisher_id, b.category_id, r.reservation_id, r.card_number
FROM books b LEFT JOIN reservations r ON b.book_id = r.book_id
WHERE b.isbn = '978-966-00-0000-0';

-- [2-8] CASCADE / SET NULL / SET DEFAULT / ON UPDATE CASCADE
DELETE FROM publishers WHERE name = 'А-БА-БА-ГА-ЛА-МА-ГА';                -- SET NULL
DELETE FROM book_categories WHERE category_id = 3;                            -- SET DEFAULT (=1)
UPDATE readers SET library_card_number = 'LIB-2025-003'
WHERE library_card_number = 'LIB-2024-003';                              -- ON UPDATE CASCADE

SELECT 'book' AS obj, book_id AS id, title AS info, publisher_id::text AS publisher, category_id::text AS category
FROM books WHERE book_id IN (4, 5) OR isbn = '978-966-00-0000-0'
UNION ALL
SELECT 'reservation', reservation_id, card_number, NULL, NULL FROM reservations
ORDER BY 1, 2;

-- [2-9] ON DELETE CASCADE: видалення книги видаляє її бронювання
DELETE FROM books WHERE isbn = '978-966-00-0000-0';
SELECT r.reservation_id, r.book_id, r.status FROM reservations r ORDER BY 1;

-- [2-10] Видалення автора, книги якого видані: RESTRICT
DELETE FROM authors WHERE last_name = 'Франко';

-- [2-11] Блокування. Вкладка A:
BEGIN;
SELECT book_id, title, available_copies FROM books WHERE book_id = 3 FOR UPDATE;
SELECT pg_sleep(40);
UPDATE books SET available_copies = available_copies - 1 WHERE book_id = 3;
COMMIT;
SELECT book_id, title, available_copies FROM books WHERE book_id = 3;

-- [2-12] Вкладка B, поки A тримає блокування: NOWAIT -> помилка
SELECT * FROM books WHERE book_id = 3 FOR UPDATE NOWAIT;

-- [2-13] Вкладка C: хто кого блокує (поки A тримає рядок, а B чекає)
SELECT a.pid, a.state, a.wait_event_type, a.wait_event,
       pg_blocking_pids(a.pid) AS blocked_by,
       left(a.query, 60) AS query
FROM pg_stat_activity a
WHERE a.datname = current_database()
  AND (a.query ILIKE '%book_id = 3%') AND a.pid <> pg_backend_pid();

-- [2-14] Вкладка B: звичайний FOR UPDATE чекає, поки A завершиться
SELECT set_config('app.t0', clock_timestamp()::text, false);
BEGIN;
SELECT book_id, available_copies FROM books WHERE book_id = 3 FOR UPDATE;
UPDATE books SET available_copies = available_copies - 1 WHERE book_id = 3;
COMMIT;
SELECT book_id, available_copies,
       clock_timestamp() - current_setting('app.t0')::timestamptz AS waited
FROM books WHERE book_id = 3;

-- [2-15] Вкладка C: SKIP LOCKED — заблокований рядок (book_id = 3) пропускається без очікування
SELECT book_id, title FROM books ORDER BY book_id FOR UPDATE SKIP LOCKED;

-- #####################################################################
-- РІВЕНЬ 3
-- #####################################################################

-- [3-1] Версіонування записів
CREATE TABLE books_versions (
    version_id     SERIAL PRIMARY KEY,
    book_id        INTEGER NOT NULL,
    version_number INTEGER NOT NULL,
    operation      VARCHAR(10) NOT NULL,
    data           JSONB NOT NULL,
    valid_from     TIMESTAMP DEFAULT clock_timestamp(),
    valid_to       TIMESTAMP,
    created_by     VARCHAR(100) DEFAULT CURRENT_USER,
    UNIQUE (book_id, version_number)
);
REVOKE ALL ON books_versions FROM anon, authenticated;

CREATE OR REPLACE FUNCTION create_book_version()
RETURNS TRIGGER AS $$
DECLARE
    v_row     books;
    v_version INTEGER;
BEGIN
    IF current_setting('app.restoring', true) = 'on' THEN
        RETURN NULL;
    END IF;
    IF TG_OP = 'DELETE' THEN v_row := OLD; ELSE v_row := NEW; END IF;

    -- закриваємо поточну версію
    UPDATE books_versions SET valid_to = clock_timestamp()
    WHERE book_id = v_row.book_id AND valid_to IS NULL;

    SELECT COALESCE(MAX(version_number), 0) + 1 INTO v_version
    FROM books_versions WHERE book_id = v_row.book_id;

    INSERT INTO books_versions (book_id, version_number, operation, data, valid_to)
    VALUES (v_row.book_id, v_version, TG_OP, to_jsonb(v_row),
            CASE WHEN TG_OP = 'DELETE' THEN clock_timestamp() END);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER book_versioning_trigger
AFTER INSERT OR UPDATE OR DELETE ON books
FOR EACH ROW EXECUTE FUNCTION create_book_version();

-- початкова версія для вже існуючих книг
INSERT INTO books_versions (book_id, version_number, operation, data)
SELECT book_id, 1, 'INITIAL', to_jsonb(b) FROM books b;

-- стан книги на момент часу
CREATE OR REPLACE FUNCTION get_book_version(p_book_id INTEGER, p_date TIMESTAMP)
RETURNS JSONB AS $$
    SELECT data FROM books_versions
    WHERE book_id = p_book_id
      AND valid_from <= p_date
      AND (valid_to IS NULL OR valid_to > p_date)
    ORDER BY version_number DESC
    LIMIT 1;
$$ LANGUAGE sql STABLE;

-- відкат книги до вказаної версії (створює нову версію)
CREATE OR REPLACE FUNCTION restore_book_version(p_book_id INTEGER, p_version INTEGER)
RETURNS books AS $$
DECLARE
    v_old books;
    v_res books;
BEGIN
    SELECT * INTO v_old FROM jsonb_populate_record(NULL::books,
        (SELECT data FROM books_versions WHERE book_id = p_book_id AND version_number = p_version));
    IF v_old.book_id IS NULL THEN
        RAISE EXCEPTION 'Версію % книги % не знайдено', p_version, p_book_id;
    END IF;
    UPDATE books SET title = v_old.title, genre = v_old.genre,
                     total_copies = v_old.total_copies, available_copies = v_old.available_copies,
                     publication_year = v_old.publication_year
    WHERE book_id = p_book_id
    RETURNING * INTO v_res;
    RETURN v_res;
END;
$$ LANGUAGE plpgsql;

-- [3-2] Демонстрація версій (кожен UPDATE окремим запуском, щоб час відрізнявся)
UPDATE books SET total_copies = 12, available_copies = available_copies + 2 WHERE book_id = 3;
UPDATE books SET title = 'Лісова пісня (ілюстроване видання)' WHERE book_id = 3;

SELECT version_number, operation, data->>'title' AS title,
       data->>'total_copies' AS total, data->>'available_copies' AS avail,
       valid_from, valid_to
FROM books_versions WHERE book_id = 3 ORDER BY version_number;

-- [3-3] Історичний стан книги на момент часу
SELECT v.version_number,
       v.valid_from + INTERVAL '1 millisecond' AS moment,
       get_book_version(3, (v.valid_from + INTERVAL '1 millisecond')::timestamp)->>'title' AS title_at_moment,
       get_book_version(3, (v.valid_from + INTERVAL '1 millisecond')::timestamp)->>'total_copies' AS total_at_moment
FROM books_versions v WHERE v.book_id = 3 ORDER BY v.version_number;

-- [3-3b] Відкат книги до версії 1 (створює нову версію)
SELECT book_id, title, total_copies, available_copies FROM restore_book_version(3, 1);
SELECT version_number, operation, data->>'title' AS title,
       data->>'total_copies' AS total, data->>'available_copies' AS avail, valid_from, valid_to
FROM books_versions WHERE book_id = 3 ORDER BY version_number;

-- [3-4] Відкладені операції
CREATE TABLE scheduled_operations (
    operation_id   SERIAL PRIMARY KEY,
    operation_type VARCHAR(50) NOT NULL
        CHECK (operation_type IN ('UPDATE_BOOK_COPIES', 'EXPIRE_RESERVATION', 'BLOCK_READER', 'ACTIVATE_READER')),
    target_table   VARCHAR(50) NOT NULL,
    operation_data JSONB NOT NULL,
    scheduled_for  TIMESTAMP NOT NULL,
    status         VARCHAR(20) DEFAULT 'Pending' CHECK (status IN ('Pending', 'Executed', 'Failed', 'Cancelled')),
    executed_at    TIMESTAMP,
    error_message  TEXT,
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
REVOKE ALL ON scheduled_operations FROM anon, authenticated;

CREATE OR REPLACE FUNCTION execute_scheduled_operations()
RETURNS INTEGER AS $$
DECLARE
    v_op    RECORD;
    v_count INTEGER := 0;
    v_rows  INTEGER;
BEGIN
    FOR v_op IN
        SELECT * FROM scheduled_operations
        WHERE status = 'Pending' AND scheduled_for <= now()
        ORDER BY scheduled_for
        FOR UPDATE SKIP LOCKED          -- паралельні виконавці не беруть одну операцію двічі
    LOOP
        BEGIN
            CASE v_op.operation_type
                WHEN 'UPDATE_BOOK_COPIES' THEN
                    UPDATE books
                    SET available_copies = (v_op.operation_data->>'available_copies')::INTEGER
                    WHERE book_id = (v_op.operation_data->>'book_id')::INTEGER;
                WHEN 'EXPIRE_RESERVATION' THEN
                    UPDATE reservations SET status = 'Expired'
                    WHERE reservation_id = (v_op.operation_data->>'reservation_id')::INTEGER
                      AND status = 'Active';
                WHEN 'BLOCK_READER' THEN
                    UPDATE readers SET status = 'Blocked'
                    WHERE reader_id = (v_op.operation_data->>'reader_id')::INTEGER;
                WHEN 'ACTIVATE_READER' THEN
                    UPDATE readers SET status = 'Active'
                    WHERE reader_id = (v_op.operation_data->>'reader_id')::INTEGER;
            END CASE;
            GET DIAGNOSTICS v_rows = ROW_COUNT;
            IF v_rows = 0 THEN
                RAISE EXCEPTION 'Цільовий запис не знайдено (%)', v_op.operation_data;
            END IF;

            UPDATE scheduled_operations SET status = 'Executed', executed_at = now()
            WHERE operation_id = v_op.operation_id;
            v_count := v_count + 1;
        EXCEPTION WHEN OTHERS THEN
            UPDATE scheduled_operations
            SET status = 'Failed', executed_at = now(), error_message = SQLERRM
            WHERE operation_id = v_op.operation_id;
        END;
    END LOOP;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Автоматичне виконання щохвилини через pg_cron
CREATE EXTENSION IF NOT EXISTS pg_cron;
SELECT cron.schedule('library-scheduled-ops', '* * * * *', 'SELECT public.execute_scheduled_operations()');

INSERT INTO scheduled_operations (operation_type, target_table, operation_data, scheduled_for) VALUES
    ('EXPIRE_RESERVATION', 'reservations', '{"reservation_id": 2}', now() + INTERVAL '1 minute'),
    ('BLOCK_READER',       'readers',      '{"reader_id": 4}',      now() + INTERVAL '1 minute'),
    ('UPDATE_BOOK_COPIES', 'books',        '{"book_id": 999, "available_copies": 1}', now() + INTERVAL '1 minute'),
    ('ACTIVATE_READER',    'readers',      '{"reader_id": 4}',      now() + INTERVAL '1 day');

SELECT operation_id, operation_type, operation_data, scheduled_for, status FROM scheduled_operations ORDER BY 1;

-- [3-4b] Бронювання №2 вже Fulfilled, тож до запуску cron операцію №1 перенацілено на активне бронювання №1
UPDATE scheduled_operations SET operation_data = '{"reservation_id": 1}'
WHERE operation_id = 1 AND status = 'Pending'
RETURNING operation_id, operation_data, status, now();

-- [3-5] Через ~2 хв: результат автоматичного виконання
SELECT operation_id, operation_type, status, executed_at, error_message
FROM scheduled_operations ORDER BY 1;

SELECT jobid, status, start_time, return_message
FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'library-scheduled-ops')
ORDER BY start_time DESC LIMIT 5;

-- [3-6] Збережені процедури: бізнес-логіка
CREATE OR REPLACE FUNCTION extend_lending(p_lending_id INTEGER, p_days INTEGER DEFAULT 7)
RETURNS TABLE (success BOOLEAN, message TEXT, new_due_date DATE) AS $$
DECLARE
    v_reader_id     INTEGER;
    v_reader_status VARCHAR(20);
    v_due           DATE;
    v_returned      DATE;
    v_overdue       INTEGER;
    v_waiting       INTEGER;
BEGIN
    SELECT l.reader_id, r.status, l.due_date, l.return_date
    INTO v_reader_id, v_reader_status, v_due, v_returned
    FROM lendings l JOIN readers r USING (reader_id)
    WHERE l.lending_id = p_lending_id
    FOR UPDATE OF l;

    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Видачу не знайдено'::TEXT, NULL::DATE; RETURN;
    END IF;
    IF v_returned IS NOT NULL THEN
        RETURN QUERY SELECT FALSE, 'Книгу вже повернуто'::TEXT, NULL::DATE; RETURN;
    END IF;
    IF v_reader_status = 'Blocked' THEN
        RETURN QUERY SELECT FALSE, 'Читач заблокований'::TEXT, NULL::DATE; RETURN;
    END IF;

    SELECT COUNT(*) INTO v_overdue FROM lendings
    WHERE reader_id = v_reader_id AND return_date IS NULL AND due_date < CURRENT_DATE;
    IF v_overdue > 0 THEN
        RETURN QUERY SELECT FALSE, 'У читача є прострочені книги'::TEXT, NULL::DATE; RETURN;
    END IF;

    SELECT COUNT(*) INTO v_waiting FROM reservations
    WHERE book_id = (SELECT book_id FROM lendings WHERE lending_id = p_lending_id) AND status = 'Active';
    IF v_waiting > 0 THEN
        RETURN QUERY SELECT FALSE, ('Книгу чекають ще ' || v_waiting || ' читач(і)')::TEXT, NULL::DATE; RETURN;
    END IF;

    UPDATE lendings SET due_date = due_date + p_days WHERE lending_id = p_lending_id;
    RETURN QUERY SELECT TRUE, 'Термін продовжено'::TEXT, (v_due + p_days)::DATE;
END;
$$ LANGUAGE plpgsql;

-- процедура видачі книги з усіма перевірками
CREATE OR REPLACE PROCEDURE issue_book(p_book_id INTEGER, p_reader_id INTEGER,
                                       p_days INTEGER DEFAULT 14, INOUT p_lending_id INTEGER DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE
    v_status VARCHAR(20);
    v_avail  INTEGER;
    v_active INTEGER;
BEGIN
    SELECT status INTO v_status FROM readers WHERE reader_id = p_reader_id;
    IF v_status IS NULL THEN RAISE EXCEPTION 'Читача % не існує', p_reader_id; END IF;
    IF v_status <> 'Active' THEN RAISE EXCEPTION 'Читач % має статус %', p_reader_id, v_status; END IF;

    SELECT COUNT(*) INTO v_active FROM lendings WHERE reader_id = p_reader_id AND return_date IS NULL;
    IF v_active >= 5 THEN RAISE EXCEPTION 'Ліміт 5 книг на руках вичерпано'; END IF;

    SELECT available_copies INTO v_avail FROM books WHERE book_id = p_book_id FOR UPDATE;
    IF v_avail IS NULL THEN RAISE EXCEPTION 'Книги % не існує', p_book_id; END IF;
    IF v_avail = 0 THEN RAISE EXCEPTION 'Немає вільних примірників книги %', p_book_id; END IF;

    INSERT INTO lendings (book_id, reader_id, due_date)
    VALUES (p_book_id, p_reader_id, CURRENT_DATE + p_days)
    RETURNING lending_id INTO p_lending_id;

    UPDATE books SET available_copies = available_copies - 1 WHERE book_id = p_book_id;
    UPDATE reservations SET status = 'Fulfilled'
    WHERE book_id = p_book_id AND reader_id = p_reader_id AND status = 'Active';
END;
$$;

-- процедура повернення книги
CREATE OR REPLACE PROCEDURE return_book(p_lending_id INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    v_book INTEGER;
BEGIN
    UPDATE lendings SET return_date = CURRENT_DATE
    WHERE lending_id = p_lending_id AND return_date IS NULL
    RETURNING book_id INTO v_book;
    IF v_book IS NULL THEN RAISE EXCEPTION 'Активну видачу % не знайдено', p_lending_id; END IF;
    UPDATE books SET available_copies = available_copies + 1 WHERE book_id = v_book;
END;
$$;

-- [3-7] Виклики
CALL issue_book(4, 1);
SELECT l.lending_id, l.book_id, r.last_name, l.due_date AS old_due, e.success, e.message, e.new_due_date
FROM lendings l JOIN readers r USING (reader_id),
     LATERAL extend_lending(l.lending_id, 14) e
WHERE l.return_date IS NULL ORDER BY l.lending_id;

-- [3-8] Процедура відмовляє заблокованому читачеві
CALL issue_book(3, 4);

-- [3-9] Система прав доступу
CREATE ROLE librarian_read;
CREATE ROLE librarian_write;
CREATE ROLE library_admin;

GRANT SELECT ON authors, books, readers, lendings, reservations, publishers, book_categories TO librarian_read;

GRANT librarian_read TO librarian_write;   -- наслідує право читання
GRANT INSERT, UPDATE ON books, lendings, reservations TO librarian_write;
GRANT UPDATE (status, phone, email) ON readers TO librarian_write;   -- лише окремі стовпці
GRANT DELETE ON reservations TO librarian_write;
GRANT INSERT ON audit_log TO librarian_write;
GRANT SELECT, INSERT, UPDATE ON books_versions TO librarian_write;
GRANT USAGE, SELECT ON SEQUENCE books_book_id_seq, lendings_lending_id_seq,
      reservations_reservation_id_seq, audit_log_log_id_seq, books_versions_version_id_seq TO librarian_write;
GRANT EXECUTE ON PROCEDURE issue_book, return_book TO librarian_write;

GRANT ALL PRIVILEGES ON authors, books, readers, lendings, reservations, publishers, book_categories,
      audit_log, books_versions, scheduled_operations TO library_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO library_admin;

-- Користувачі без права входу: база доступна з інтернету, а файл лежить у публічному репозиторії.
-- У реальній системі: CREATE USER librarian1 WITH PASSWORD '...';
CREATE ROLE librarian1 NOLOGIN;
CREATE ROLE librarian2 NOLOGIN;
CREATE ROLE admin1     NOLOGIN;

GRANT librarian_read  TO librarian1;
GRANT librarian_write TO librarian2;
GRANT library_admin   TO admin1;
GRANT librarian1, librarian2, admin1 TO postgres;   -- щоб postgres міг робити SET ROLE

SELECT grantee, table_name, string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privileges
FROM information_schema.role_table_grants
WHERE grantee IN ('librarian_read', 'librarian_write', 'library_admin')
GROUP BY grantee, table_name ORDER BY grantee, table_name;

-- [3-10] librarian1: читання дозволено
SET LOCAL ROLE librarian1;
SELECT current_user, COUNT(*) AS books FROM books;

-- [3-11] librarian1: оновлення заборонено
SET LOCAL ROLE librarian1;
UPDATE books SET available_copies = 5 WHERE book_id = 1;

-- [3-12] librarian2: оновлення книги дозволено, і в аудиті видно, хто змінив
SET LOCAL ROLE librarian2;
UPDATE books SET available_copies = available_copies - 1 WHERE book_id = 5;
RESET ROLE;
SELECT log_id, table_name, operation, record_id, changed_by FROM audit_log ORDER BY log_id DESC LIMIT 3;

-- [3-13] librarian2: видалення автора та зміна імені читача заборонені
SET LOCAL ROLE librarian2;
DELETE FROM authors WHERE author_id = 1;

-- [3-13b] librarian2: зміна імені читача (немає права UPDATE на стовпець first_name)
SET LOCAL ROLE librarian2;
UPDATE readers SET first_name = 'Хтось' WHERE reader_id = 1;

-- [3-14] Контрольні точки та відновлення після збою
CREATE TABLE backup_points (
    backup_id        SERIAL PRIMARY KEY,
    backup_name      VARCHAR(100) NOT NULL,
    backup_timestamp TIMESTAMP DEFAULT clock_timestamp(),
    description      TEXT,
    data_snapshot    JSONB NOT NULL
);
REVOKE ALL ON backup_points FROM anon, authenticated;

CREATE OR REPLACE FUNCTION create_backup_point(p_name VARCHAR, p_description TEXT DEFAULT NULL)
RETURNS INTEGER AS $$
DECLARE
    v_id INTEGER;
BEGIN
    INSERT INTO backup_points (backup_name, description, data_snapshot)
    SELECT p_name, p_description, jsonb_build_object(
        'publishers',   COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM publishers x), '[]'),
        'book_categories',   COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM book_categories x), '[]'),
        'authors',      COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM authors x), '[]'),
        'books',        COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM books x), '[]'),
        'readers',      COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM readers x), '[]'),
        'lendings',     COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM lendings x), '[]'),
        'reservations', COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM reservations x), '[]'))
    RETURNING backup_id INTO v_id;
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION restore_from_backup(p_backup_id INTEGER)
RETURNS TABLE (table_name TEXT, restored_rows BIGINT) AS $$
DECLARE
    s JSONB;
BEGIN
    SELECT data_snapshot INTO s FROM backup_points WHERE backup_id = p_backup_id;
    IF s IS NULL THEN
        RAISE EXCEPTION 'Контрольну точку % не знайдено', p_backup_id;
    END IF;

    -- перед відновленням автоматично зберігаємо поточний стан
    PERFORM create_backup_point('auto: before restore #' || p_backup_id, 'Створено автоматично');

    PERFORM set_config('app.restoring', 'on', true);   -- вимикаємо аудит до кінця транзакції

    TRUNCATE lendings, reservations, books, readers, authors, publishers, book_categories;

    INSERT INTO book_categories   SELECT * FROM jsonb_populate_recordset(NULL::book_categories,   s->'book_categories');
    INSERT INTO publishers   SELECT * FROM jsonb_populate_recordset(NULL::publishers,   s->'publishers');
    INSERT INTO authors      SELECT * FROM jsonb_populate_recordset(NULL::authors,      s->'authors');
    INSERT INTO books        SELECT * FROM jsonb_populate_recordset(NULL::books,        s->'books');
    INSERT INTO readers      SELECT * FROM jsonb_populate_recordset(NULL::readers,      s->'readers');
    INSERT INTO lendings     SELECT * FROM jsonb_populate_recordset(NULL::lendings,     s->'lendings');
    INSERT INTO reservations SELECT * FROM jsonb_populate_recordset(NULL::reservations, s->'reservations');

    -- лічильники SERIAL після вставки з явними id
    PERFORM setval('authors_author_id_seq',           COALESCE((SELECT MAX(author_id) FROM authors), 0) + 1, false);
    PERFORM setval('books_book_id_seq',               COALESCE((SELECT MAX(book_id) FROM books), 0) + 1, false);
    PERFORM setval('readers_reader_id_seq',           COALESCE((SELECT MAX(reader_id) FROM readers), 0) + 1, false);
    PERFORM setval('lendings_lending_id_seq',         COALESCE((SELECT MAX(lending_id) FROM lendings), 0) + 1, false);
    PERFORM setval('reservations_reservation_id_seq', COALESCE((SELECT MAX(reservation_id) FROM reservations), 0) + 1, false);
    PERFORM setval('publishers_publisher_id_seq',     COALESCE((SELECT MAX(publisher_id) FROM publishers), 0) + 1, false);

    PERFORM set_config('app.restoring', 'off', true);

    RETURN QUERY
    SELECT k, jsonb_array_length(s->k)::bigint
    FROM unnest(ARRAY['book_categories','publishers','authors','books','readers','lendings','reservations']) AS k;
END;
$$ LANGUAGE plpgsql;

-- автоматична контрольна точка щодня о 02:00
SELECT cron.schedule('library-daily-backup', '0 2 * * *',
       $$SELECT public.create_backup_point('auto: daily ' || to_char(now(), 'YYYY-MM-DD'), 'pg_cron')$$);

SELECT create_backup_point('Before major update', 'Ручна контрольна точка перед «збоєм»');
SELECT jobname, schedule, command FROM cron.job WHERE jobname LIKE 'library-%';

-- [3-15] «Збій»: помилкові операції без WHERE
UPDATE books SET available_copies = 0;
DELETE FROM reservations;
SELECT book_id, title, available_copies FROM books ORDER BY book_id;

-- [3-16] Відновлення
SELECT * FROM restore_from_backup((SELECT MAX(backup_id) FROM backup_points
                                   WHERE backup_name = 'Before major update'));

-- [3-17] Перевірка
SELECT book_id, title, available_copies, total_copies FROM books ORDER BY book_id;

-- [3-18] Інтерфейс перегляду історії
CREATE OR REPLACE VIEW books_change_history AS
SELECT a.log_id,
       a.operation,
       a.record_id AS book_id,
       COALESCE(a.new_data->>'title', a.old_data->>'title') AS title,
       CASE
           WHEN a.operation = 'INSERT' THEN 'Додано нову книгу'
           WHEN a.operation = 'DELETE' THEN 'Видалено книгу'
           ELSE 'Оновлено: ' || (
               SELECT string_agg(n.key || ': ' || COALESCE(a.old_data->>n.key, 'NULL')
                                 || ' → ' || COALESCE(n.value #>> '{}', 'NULL'), '; ')
               FROM jsonb_each(a.new_data) n
               WHERE n.value IS DISTINCT FROM a.old_data->n.key)
       END AS change_description,
       a.changed_at,
       a.changed_by
FROM audit_log a
WHERE a.table_name = 'books';

-- зведена історія по всіх таблицях
CREATE OR REPLACE VIEW all_changes_history AS
SELECT a.log_id, a.table_name, a.operation, a.record_id,
       (SELECT jsonb_object_agg(n.key, jsonb_build_array(a.old_data->n.key, n.value))
        FROM jsonb_each(a.new_data) n
        WHERE a.operation = 'UPDATE' AND n.value IS DISTINCT FROM a.old_data->n.key) AS changed_fields,
       a.changed_at, a.changed_by
FROM audit_log a;

REVOKE ALL ON books_change_history, all_changes_history FROM anon, authenticated;
GRANT SELECT ON books_change_history, all_changes_history TO librarian_read, library_admin;

CREATE OR REPLACE FUNCTION get_changes_report(p_start_date TIMESTAMP, p_end_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP)
RETURNS TABLE (change_date DATE, table_name VARCHAR, total_changes BIGINT,
               inserts BIGINT, updates BIGINT, deletes BIGINT) AS $$
    SELECT DATE(a.changed_at), a.table_name, COUNT(*),
           COUNT(*) FILTER (WHERE a.operation = 'INSERT'),
           COUNT(*) FILTER (WHERE a.operation = 'UPDATE'),
           COUNT(*) FILTER (WHERE a.operation = 'DELETE')
    FROM audit_log a
    WHERE a.changed_at BETWEEN p_start_date AND p_end_date
    GROUP BY 1, 2 ORDER BY 1 DESC, 2;
$$ LANGUAGE sql STABLE;

-- відкат усіх змін книг за період (у зворотному порядку)
CREATE OR REPLACE FUNCTION rollback_books_changes(p_from TIMESTAMP, p_to TIMESTAMP DEFAULT clock_timestamp())
RETURNS TABLE (log_id INTEGER, operation VARCHAR, book_id INTEGER, action TEXT) AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT * FROM audit_log a
        WHERE a.table_name = 'books' AND a.changed_at BETWEEN p_from AND p_to
        ORDER BY a.log_id DESC
    LOOP
        IF r.operation = 'UPDATE' THEN
            UPDATE books b SET (title, isbn, author_id, publication_year, genre, total_copies,
                                available_copies, publisher_id, category_id) =
                (SELECT o.title, o.isbn, o.author_id, o.publication_year, o.genre, o.total_copies,
                        o.available_copies, o.publisher_id, o.category_id
                 FROM jsonb_populate_record(NULL::books, r.old_data) o)
            WHERE b.book_id = r.record_id;
            action := 'повернуто старі значення';
        ELSIF r.operation = 'INSERT' THEN
            DELETE FROM books b WHERE b.book_id = r.record_id;
            action := 'видалено додану книгу';
        ELSE
            INSERT INTO books SELECT * FROM jsonb_populate_record(NULL::books, r.old_data);
            action := 'відновлено видалену книгу';
        END IF;
        log_id := r.log_id; operation := r.operation; book_id := r.record_id;
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- [3-19] Перегляд історії
SELECT log_id, operation, book_id, title, change_description, changed_by
FROM books_change_history ORDER BY log_id DESC LIMIT 12;

-- [3-20] Звіт за період
SELECT * FROM get_changes_report((CURRENT_DATE - INTERVAL '30 days')::timestamp);

-- [3-21] Відкат змін за період: дві помилкові зміни і їх скасування
-- у SQL Editor кожен запуск — окремий сеанс, тому мітку часу зберігаємо в backup_points
INSERT INTO backup_points (backup_name, description, data_snapshot)
VALUES ('mark: before mistakes', 'мітка часу для rollback_books_changes', '{}');
UPDATE books SET genre = 'ПОМИЛКА', available_copies = 0 WHERE book_id IN (1, 2);
SELECT book_id, title, genre, available_copies FROM books WHERE book_id IN (1, 2);

-- [3-22] Відкат змін книг за період (від мітки до поточного моменту)
SELECT * FROM rollback_books_changes(
    (SELECT backup_timestamp FROM backup_points WHERE backup_name = 'mark: before mistakes'));
SELECT book_id, title, genre, available_copies FROM books WHERE book_id IN (1, 2);
