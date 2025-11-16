-- filepath: /Users/ramesh/Documents/Learnings/gc-codings/postgresql-project/primary-init/init.sql
CREATE TABLE test_table (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO
    test_table (name)
VALUES
    ('Initial Data');
