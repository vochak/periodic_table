#!/bin/bash

PSQL="psql -X --username=freecodecamp --dbname=periodic_table --tuples-only -c"

MAIN_PROGRAM() {
  [[ -z $1 ]] && echo "Please provide an element as an argument." || PRINT_ELEMENT $1
}

PRINT_ELEMENT() {
  local INPUT=$1
  local ATOMIC_NUMBER

  if [[ ! $INPUT =~ ^[0-9]+$ ]]; then
    ATOMIC_NUMBER=$(echo $($PSQL "SELECT atomic_number FROM elements WHERE symbol='$INPUT' OR name='$INPUT';") | xargs)
  else
    ATOMIC_NUMBER=$(echo $($PSQL "SELECT atomic_number FROM elements WHERE atomic_number=$INPUT;") | xargs)
  fi

  [[ -z $ATOMIC_NUMBER ]] && { echo "I could not find that element in the database."; return; }

  local NAME SYMBOL TYPE ATOMIC_MASS MELTING_POINT_CELSIUS BOILING_POINT_CELSIUS
  NAME=$(echo $($PSQL "SELECT name FROM elements WHERE atomic_number=$ATOMIC_NUMBER;") | xargs)
  SYMBOL=$(echo $($PSQL "SELECT symbol FROM elements WHERE atomic_number=$ATOMIC_NUMBER;") | xargs)
  TYPE=$(echo $($PSQL "SELECT type FROM types JOIN properties ON types.type_id = properties.type_id WHERE atomic_number=$ATOMIC_NUMBER;") | xargs)
  ATOMIC_MASS=$(echo $($PSQL "SELECT atomic_mass FROM properties WHERE atomic_number=$ATOMIC_NUMBER;") | xargs)
  MELTING_POINT_CELSIUS=$(echo $($PSQL "SELECT melting_point_celsius FROM properties WHERE atomic_number=$ATOMIC_NUMBER;") | xargs)
  BOILING_POINT_CELSIUS=$(echo $($PSQL "SELECT boiling_point_celsius FROM properties WHERE atomic_number=$ATOMIC_NUMBER;") | xargs)

  echo "The element with atomic number $ATOMIC_NUMBER is $NAME ($SYMBOL). It's a $TYPE, with a mass of $ATOMIC_MASS amu. $NAME has a melting point of $MELTING_POINT_CELSIUS celsius and a boiling point of $BOILING_POINT_CELSIUS celsius."
}

FIX_DB() {
  echo "RENAMING COLUMNS AND ADDING CONSTRAINTS..."
  $PSQL "ALTER TABLE properties RENAME COLUMN weight TO atomic_mass;"
  $PSQL "ALTER TABLE properties RENAME COLUMN melting_point TO melting_point_celsius;"
  $PSQL "ALTER TABLE properties RENAME COLUMN boiling_point TO boiling_point_celsius;"
  $PSQL "ALTER TABLE properties ALTER COLUMN melting_point_celsius SET NOT NULL;"
  $PSQL "ALTER TABLE properties ALTER COLUMN boiling_point_celsius SET NOT NULL;"
  $PSQL "ALTER TABLE elements ADD UNIQUE(symbol);"
  $PSQL "ALTER TABLE elements ADD UNIQUE(name);"
  $PSQL "ALTER TABLE elements ALTER COLUMN symbol SET NOT NULL;"
  $PSQL "ALTER TABLE elements ALTER COLUMN name SET NOT NULL;"
  $PSQL "ALTER TABLE properties ADD FOREIGN KEY (atomic_number) REFERENCES elements(atomic_number);"

  echo "CREATING TYPES TABLE..."
  $PSQL "CREATE TABLE IF NOT EXISTS types (type_id SERIAL PRIMARY KEY, type VARCHAR(20) NOT NULL);"
  $PSQL "INSERT INTO types(type) SELECT DISTINCT(type) FROM properties;"

  echo "ADDING type_id COLUMN TO properties TABLE..."
  $PSQL "ALTER TABLE properties ADD COLUMN type_id INT;"
  $PSQL "UPDATE properties SET type_id = (SELECT type_id FROM types WHERE properties.type = types.type);"
  $PSQL "ALTER TABLE properties ALTER COLUMN type_id SET NOT NULL;"
  $PSQL "ALTER TABLE properties ADD FOREIGN KEY(type_id) REFERENCES types(type_id);"

  echo "UPDATING SYMBOLS AND ATOMIC MASSES..."
  $PSQL "UPDATE elements SET symbol = INITCAP(symbol);"
  $PSQL "ALTER TABLE properties ALTER COLUMN atomic_mass TYPE VARCHAR(9);"
  $PSQL "UPDATE properties SET atomic_mass = CAST(atomic_mass AS FLOAT);"

  echo "ADDING ELEMENTS..."
  $PSQL "INSERT INTO elements(atomic_number, symbol, name) VALUES (9, 'F', 'Fluorine');"
  $PSQL "INSERT INTO properties(atomic_number, type, melting_point_celsius, boiling_point_celsius, type_id, atomic_mass) VALUES (9, 'nonmetal', -220, -188.1, 3, '18.998');"
  $PSQL "INSERT INTO elements(atomic_number, symbol, name) VALUES (10, 'Ne', 'Neon');"
  $PSQL "INSERT INTO properties(atomic_number, type, melting_point_celsius, boiling_point_celsius, type_id, atomic_mass) VALUES (10, 'nonmetal', -248.6, -246.1, 3, '20.18');"

  echo "REMOVING NON-EXISTENT ELEMENTS..."
  $PSQL "DELETE FROM properties WHERE atomic_number=1000;"
  $PSQL "DELETE FROM elements WHERE atomic_number=1000;"

  echo "REMOVING type COLUMN..."
  $PSQL "ALTER TABLE properties DROP COLUMN type;"
}

START_PROGRAM() {
  local CHECK=$($PSQL "SELECT COUNT(*) FROM elements WHERE atomic_number=1000;" | xargs)
  [[ $CHECK -gt 0 ]] && { FIX_DB; clear; }
  MAIN_PROGRAM $1
}

START_PROGRAM $1
