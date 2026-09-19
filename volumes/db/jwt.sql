-- Initialize the database's JWT expiry setting. Runs once, at first DB init.
\set jwt_exp `echo "$JWT_EXP"`

ALTER DATABASE postgres SET "app.settings.jwt_exp" TO :'jwt_exp';
