CREATE OR REPLACE PACKAGE ps_parse
IS
--
/*

***************************************************************************
Header: ps_parse,v 1.0 00/11 12:00:00

       System  : 
       Module  : PS_PARSE
       Purpose : Parse data strings
       Author  : O'Reilly
***************************************************************************

*/
--
--
--
   /*
   || PL/SQL table structures to hold atomics retrieved by parse_string.
   || This includes the table type definition, a table (though you can
   || declare your own as well, and an empty table, which you can use
   || to clear out your table which contains atomics.
   */
   TYPE atoms_tabtype IS TABLE OF VARCHAR2 ( 32767 )
      INDEX BY BINARY_INTEGER;

   atoms_table                   atoms_tabtype;
   empty_atoms_table             atoms_tabtype;
   /*
   || The standard list of delimiters. You can over-ride these with
   || your own list when you call the procedures and functions below.
   || This list is a pretty standard set of delimiters, though.
   */
   std_delimiters                VARCHAR2 ( 50 )
                                          := ' !@#$%^&*()-_=+\|`~{[]};:",<.>/?';

   /* Display contents of table using DBMS_OUTPUT */
   PROCEDURE display_atomics (
      table_in                   IN       atoms_tabtype
,     num_rows_in                IN       NUMBER );

   /*
   || The parse_string procedure: I provide two, overloaded definitions.
   || The first version puts all atomics into a PL/SQL table and would
   || be used in a PL/SQL Version 2 environment. The second version places
   || all atomics into a string, separating each atomic by a vertical bar.
   || (My code does NOT do any special handling when it finds a "|" in
   || the string. You have to deal with that when you extract the atomics.
   ||
   || See the program definition for more details on other parameters.
   */
   PROCEDURE parse_string (
      string_in                  IN       VARCHAR2
,     atomics_list_out           OUT      atoms_tabtype
,     num_atomics_out            IN OUT   NUMBER
,     delimiters_in              IN       VARCHAR2 := std_delimiters );

   PROCEDURE parse_string (
      string_in                  IN       VARCHAR2
,     atomics_list_out           IN OUT   VARCHAR2
,     num_atomics_out            IN OUT   NUMBER
,     delimiters_in              IN       VARCHAR2 := std_delimiters );

   /* Count the number of atomics in a string */
   FUNCTION number_of_atomics (
      string_in                  IN       VARCHAR2
,     count_type_in              IN       VARCHAR2 := 'ALL'
,     delimiters_in              IN       VARCHAR2 := std_delimiters )
      RETURN INTEGER;

   /* Return the Nth atomic in the string */
   FUNCTION nth_atomic (
      string_in                  IN       VARCHAR2
,     nth_in                     IN       NUMBER
,     count_type_in              IN       VARCHAR2 := 'ALL'
,     delimiters_in              IN       VARCHAR2 := std_delimiters )
      RETURN VARCHAR2;

   PRAGMA RESTRICT_REFERENCES ( number_of_atomics, WNDS );
END ps_parse;
/
CREATE OR REPLACE PACKAGE BODY ps_parse
IS
   /* Package variables used repeatedly throughout the body. */
   len_string                    NUMBER;
   start_loc                     NUMBER;
   next_loc                      NUMBER;
   /*
   || Since the PUT_LINE procedure regards a string of one or more
   || spaces as NULL, it will not display a space, which is in
   || PS_Parse a valid atomic. So I save a_blank in the PL/SQL
   || table instead of the space itself.
   */
   a_blank              CONSTANT VARCHAR2 ( 3 ) := '" "';

   /*--------------------- Private Modules ---------------------------
   || The following functions are available only to other modules in
   || package. No user of PS_Parse can see or use these functions.
   ------------------------------------------------------------------*/
   FUNCTION a_delimiter (
      character_in               IN       VARCHAR2
,     delimiters_in              IN       VARCHAR2 := std_delimiters )
      RETURN BOOLEAN
   /*
   || Returns TRUE if the character passsed into the function is found
   || in the list of delimiters.
   */
   IS
   BEGIN
      RETURN INSTR ( delimiters_in, character_in ) > 0;
   END;

   FUNCTION string_length (
      string_in                  IN       VARCHAR2 )
      RETURN INTEGER
   IS
   BEGIN
      RETURN LENGTH ( LTRIM ( RTRIM ( string_in )));
   END;

   FUNCTION next_atom_loc (
      string_in                  IN       VARCHAR2
,     start_loc_in               IN       NUMBER
,     scan_increment_in          IN       NUMBER := +1 )
      /*
      || The next_atom_loc function returns the location
      || in the string of the starting point of the next atomic (from the
      || start location). The function scans forward if scan_increment_in is
      || +1, otherwise it scans backwards through the string. Here is the
      || logic to determine when the next atomic starts:
      ||
      ||      1. If current atomic is a delimiter (if, that is, the character
      ||         at the start_loc_in of the string is a delimiter), then the
      ||         the next character starts the next atomic since all
      ||         delimiters are a single character in length.
      ||
      ||      2. If current atomic is a word (if, that is, the character
      ||         at the start_loc_in of the string is a delimiter), then the
      ||         next atomic starts at the next delimiter. Any letters or
      ||         numbers in between are part of the current atomic.
      ||
      || So I loop through the string a character at a time and apply these
      || tests. I also have to check for end of string. If I scan forward
      || the end of string comes when the SUBSTR which pulls out the next
      || character returns NULL. If I scan backward, then the end of the
      || string comes when the location is less than 0.
      */
   RETURN NUMBER
   IS
      /* Boolean variable which uses private function to determine
      || if the current character is a delimiter or not.
      */
      was_a_delimiter               BOOLEAN
               := ps_parse.a_delimiter ( SUBSTR ( string_in
,                                                 start_loc_in
,                                                 1 ));
      /* If not a delimiter, then it was a word. */
      was_a_word                    BOOLEAN := NOT was_a_delimiter;
      /* The next character scanned in the string */
      next_char                     VARCHAR2 ( 1 );
      /*
      || The value returned by the function. This location is the start
      || of the next atomic found. Initialize it to next character,
      || forward or backward depending on increment.
      */
      return_value                  NUMBER := start_loc_in + scan_increment_in;
   BEGIN
      LOOP
         -- Extract the next character.
         next_char := SUBSTR ( string_in
,                              return_value
,                              1 );
         -- Exit the loop if:
         EXIT WHEN
                  /* On a delimiter, since that is always an atomic */
                  a_delimiter ( next_char )
               OR 
                  /* Was a delimiter, but am now in a word. */
                  ( was_a_delimiter AND NOT a_delimiter ( next_char ))
               OR
                  /* Reached end of string scanning forward. */
                  next_char IS NULL
               OR
                  /* Reached beginning of string scanning backward. */
                  return_value < 0;
         /* Shift return_value to move the next character. */
         return_value := return_value + scan_increment_in;
      END LOOP;

      -- If the return_value is negative, return 0, else the return_value
      RETURN GREATEST ( return_value, 0 );
   END;

   PROCEDURE increment_counter (
      counter_inout              IN OUT   NUMBER
,     count_type_in              IN       VARCHAR2
,     atomic_in                  IN       CHAR )
       /*
       || The increment_counter procedure is used by nth_atomic and
       || number_of_atomics to add to the count of of atomics. Since you
       || can request a count by ALL atomics, just the WORD atomics or
       || just the DELIMITER atomics. I use the a_delimiter function to
       || decide whether I should add to the counter. This is not a terribly
       || complex procedure. I bury this logic into a separate module,
   however,
       || to make it easier to read and debug the main body of the programs.
       */
   IS
   BEGIN
      IF    count_type_in = 'ALL'
         OR ( count_type_in = 'WORD' AND NOT a_delimiter ( atomic_in ))
         OR ( count_type_in = 'DELIMITER' AND a_delimiter ( atomic_in ))
      THEN
         counter_inout := counter_inout + 1;
      END IF;
   END increment_counter;

   /* ------------------------- Public Modules -----------------------*/
   PROCEDURE display_atomics (
      table_in                   IN       atoms_tabtype
,     num_rows_in                IN       NUMBER )
   /*
   || Program to dump out contents of table. Notice I must also pass in
   || the number of rows in the table so that I know when to stop the
   || loop. Otherwise I will raise a NO_DATA_FOUND exception. For a more
   || elaborate display_table module, see Chapter 7 on PL/SQL tables.
   */
   IS
   BEGIN
      FOR table_row IN 1 .. num_rows_in
      LOOP
         dbms_output.put_line ( NVL ( table_in ( table_row ), 'NULL' ));
      END LOOP;
   END;

   PROCEDURE parse_string (
      string_in                  IN       VARCHAR2
,     atomics_list_out           OUT      atoms_tabtype
,     num_atomics_out            IN OUT   NUMBER
,     delimiters_in              IN       VARCHAR2 := std_delimiters )
   /*
   || Version of parse_string which stores the list of atomics
   || in a PL/SQL table.
   ||
   || Parameters:
   ||      string_in - the string to be parsed.
   ||      atomics_list_out - the table of atomics.
   ||      num_atomics_out - the number of atomics found.
   ||      delimiters_in - the set of delimiters used in parse.
   */
   IS
   BEGIN
      /* Initialize variables. */
      num_atomics_out := 0;
      len_string := string_length ( string_in );

      IF len_string IS NOT NULL
      THEN
         /*
         || Only scan the string if made of something more than blanks.
         || Start at first non-blank character. Remember: INSTR returns 0
         || if a space is not found. Stop scanning if at end of string.
         */
         start_loc := LEAST ( 1, INSTR ( string_in, ' ' ) + 1 );

         WHILE start_loc <= len_string
         LOOP
            /*
            || Find the starting point of the NEXT atomic. Go ahead and
            || increment counter for the number of atomics. Then have to
            || actually pull out the atomic. Two cases to consider:
            ||      1. Last atomic goes to end of string.
            ||      2. The atomic is a single blank. Use special constant.
            ||      3. Anything else.
            */
            next_loc := next_atom_loc ( string_in, start_loc );
            num_atomics_out := num_atomics_out + 1;

            IF next_loc > len_string
            THEN
               -- Atomic is all characters right to the end of the string.
               atomics_list_out ( num_atomics_out ) :=
                                                SUBSTR ( string_in, start_loc );
            ELSE
               /*
               || Internal atomic. If RTRIMs to NULL, have a blank
               || Use special-case string to stuff a " " in the table.
               */
               atomics_list_out ( num_atomics_out ) :=
                  NVL ( RTRIM ( SUBSTR ( string_in
,                                        start_loc
,                                        next_loc - start_loc ))
,                       a_blank );
            END IF;

            -- Move starting point of scan for next atomic.
            start_loc := next_loc;
         END LOOP;
      END IF;
   END parse_string;

   PROCEDURE parse_string (
      string_in                  IN       VARCHAR2
,     atomics_list_out           IN OUT   VARCHAR2
,     num_atomics_out            IN OUT   NUMBER
,     delimiters_in              IN       VARCHAR2 := std_delimiters )
   /*
   || The version of parse_string which writes the atomics out to a packed
   || list in the format "|A|,|C|". I do not repeat any of the comments
   || from the first iteration of parse_string.
   */
   IS
   BEGIN
      /* Initialize variables */
      num_atomics_out := 0;
      atomics_list_out := NULL;
      len_string := string_length ( string_in );

      IF len_string IS NOT NULL
      THEN
         start_loc := LEAST ( 1, INSTR ( string_in, ' ' ) + 1 );

         WHILE start_loc <= len_string
         LOOP
            next_loc := next_atom_loc ( string_in, start_loc );
            num_atomics_out := num_atomics_out + 1;

            IF next_loc > len_string
            THEN
               atomics_list_out :=
                     atomics_list_out || '|' || SUBSTR ( string_in, start_loc );
            ELSE
               atomics_list_out :=
                     atomics_list_out
                  || '|'
                  || NVL ( RTRIM ( SUBSTR ( string_in
,                                           start_loc
,                                           next_loc - start_loc ))
,                          a_blank );
            END IF;

            start_loc := next_loc;
         END LOOP;

         /* Apply terminating delimiter to the string. */
         atomics_list_out := atomics_list_out || '|';
      END IF;
   END parse_string;

   FUNCTION number_of_atomics (
      string_in                  IN       VARCHAR2
,     count_type_in              IN       VARCHAR2 := 'ALL'
,     delimiters_in              IN       VARCHAR2 := std_delimiters )
      RETURN INTEGER
   /*
   || Counts the number of atomics in the string_in. You can specify the
   || type of count you want: ALL for all atomics, WORD to count only the
   || words and DELIMITER to count only the delimiters. You can optionally
   || pass your own set of delimiters into the function.
   */
   IS
      return_value                  INTEGER := 0;
   BEGIN
      /* Initialize variables. */
      len_string := string_length ( string_in );

      IF len_string IS NOT NULL
      THEN
         /*
         || This loop is much simpler than parse_string. Call the
         || next_atom_loc to move to the next atomic and increment the
         || counter if appropriate. Everything complicated is shifted into
         || sub-programs so that you can read the program "top-down",
         || understand it layer by layer.
         */
         start_loc := LEAST ( 1, INSTR ( string_in, ' ' ) + 1 );

         WHILE start_loc <= len_string
         LOOP
            increment_counter ( return_value
,                               UPPER ( count_type_in )
,                               SUBSTR ( string_in
,                                        start_loc
,                                        1 ));
            start_loc := next_atom_loc ( string_in, start_loc );
         END LOOP;
      END IF;

      RETURN return_value;
   END number_of_atomics;

   FUNCTION nth_atomic (
      string_in                  IN       VARCHAR2
,     nth_in                     IN       NUMBER
,     count_type_in              IN       VARCHAR2 := 'ALL'
,     delimiters_in              IN       VARCHAR2 := std_delimiters )
      RETURN VARCHAR2
   /*
   || Find and return the nth atomic in a string. If nth_in is greater
   || the number of atomics, then return NULL. If nth_in is negative the
   || function counts from the back of the string. You can again request
   || a retrieval by ALL atomics, just the WORDs or just the DELIMITER.
   || So you can ask for the third atomic, or the second word from the end
   || of the string. You can pass your own list of delimiters as well.
   */
   IS
      /* Local copy of string. Supports up to 1000 characters. */
      local_string                  VARCHAR2 ( 1000 )
                             := LTRIM ( RTRIM ( SUBSTR ( string_in
,                                                        1
,                                                        1000 )));
      /* Running count of atomics so far counted. */
      atomic_count                  NUMBER := 1;
      /* Boolean variable which controls the looping logic. */
      still_scanning                BOOLEAN
                                     := local_string IS NOT NULL AND nth_in != 0;
      /* The amount by which I increment the counter. */
      scan_increment                INTEGER;
      /* Return value of function, maximum length of 100 characters. */
      return_value                  VARCHAR2 ( 100 ) := NULL;
   BEGIN
      IF nth_in = 0
      THEN
         /* Not much to do here. Find 0th atomic? */
         RETURN NULL;
      ELSE
         /* Initialize the loop variables. */
         len_string := string_length ( local_string );

         IF nth_in > 0
         THEN
            /* Start at first non-blank character and scan forward. */
            next_loc := 1;
            scan_increment := 1;
         ELSE
            /* Start at last non-blank character and scan backward. */
            next_loc := len_string;
            scan_increment := -1;
         END IF;

         /* Loop through the string until the Boolean is FALSE. */
         WHILE still_scanning
         LOOP
            /* Move start of scan in string to loc of last atomic. */
            start_loc := next_loc;
            /* Find the starting point of the next atomic. */
            next_loc :=
                      next_atom_loc ( local_string
,                                     start_loc
,                                     scan_increment );
            /* Increment the count of atomics. */
            increment_counter ( atomic_count
,                               UPPER ( count_type_in )
,                               SUBSTR ( local_string
,                                        start_loc
,                                        1 ));
            /*
            || Keep scanning if my count hasn't exceeded the request
            || and I am neither at the beginning nor end of the string.
            */
            still_scanning :=
                   atomic_count <= ABS ( nth_in )
               AND next_loc <= len_string
               AND next_loc >= 1;
         END LOOP;

         /*
         || Done with the loop. If my count has not exceeded the requested
         || amount, then there weren't enough atomics in the string to
         || satisfy the request.
         */
         IF atomic_count <= ABS ( nth_in )
         THEN
            RETURN NULL;
         ELSE
            /*
            || I need to extract the atomic from the string. If scanning
            || forward, then I start at start_loc and SUBSTR forward.
            || If I am scanning backwards, I start at next_loc+1 (next_loc
            || is the starting point of the NEXT atomic and I want the
            || current one) and SUBSTR forward (when scanning in
            || reverse, next_loc comes before start_loc in the string.
            */
            IF scan_increment = +1
            THEN
               RETURN SUBSTR ( local_string
,                              start_loc
,                              next_loc - start_loc );
            ELSE
               RETURN SUBSTR ( local_string
,                              next_loc + 1
,                              start_loc - next_loc );
            END IF;
         END IF;
      END IF;
   END nth_atomic;
END ps_parse;
/
