CREATE OR REPLACE PACKAGE BODY cs_print_utility
AS
   PROCEDURE print_output(
      p_message   IN   VARCHAR2
    , p_mode      IN   VARCHAR2 DEFAULT 'LOG')
   IS
      l_mode   VARCHAR2(10) := p_mode;
   BEGIN
      IF p_print_output_mode IS NOT NULL THEN
         l_mode    := p_print_output_mode;
      END IF;

      IF l_mode = 'OUTPUT' THEN
         fnd_file.put_line(fnd_file.output, p_message);
      ELSIF l_mode = 'DBMS'  -- Displays DBMS_OUTPUT from 1 to 1000 characters
                           THEN
         DBMS_OUTPUT.put_line(SUBSTR(p_message, 1, 250));

         IF LENGTH(p_message) > 250 THEN
            DBMS_OUTPUT.put_line(SUBSTR(p_message, 251, 250));
         END IF;

         IF LENGTH(p_message) > 501 THEN
            DBMS_OUTPUT.put_line(SUBSTR(p_message, 501, 250));
         END IF;

         IF LENGTH(p_message) > 751 THEN
            DBMS_OUTPUT.put_line(SUBSTR(p_message, 751, 250));
         END IF;
      ELSE
         fnd_file.put_line(fnd_file.LOG, p_message);
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         NULL;             -- Ignore errors... protect buffer overflow's etc.
   END print_output;

--
-- PRINT_OUTPUT
--
-- Displays content to DBMS_OUTPUT, but only when g_debug_flag is set to Y .
--
   PROCEDURE print_output(p_message IN VARCHAR2, p_size IN NUMBER DEFAULT 250)
   IS
      c_process   CONSTANT VARCHAR2(100)   := 'PRINT_OUTPUT';
      l_message            VARCHAR2(32000);
      l_len                PLS_INTEGER;
      l_display_size       PLS_INTEGER     := NVL(p_size, 250);
      l_pos                PLS_INTEGER     := 0;
      l_max_line_size      PLS_INTEGER     := LEAST(l_display_size, 250);
   BEGIN
      IF NVL(g_debug_flag, 'N') = 'Y' THEN
--
         l_pos        := 1;
         l_message    := SUBSTR(p_message, l_pos, l_max_line_size);
         l_len        := NVL(LENGTH(l_message), 0);

--
         WHILE l_len > 0 LOOP
--
            DBMS_OUTPUT.put_line(SUBSTR(l_message, l_pos, l_max_line_size));

            IF l_display_size > l_max_line_size THEN
               l_pos        := l_pos + l_max_line_size;
               l_message    := SUBSTR(p_message, l_pos, l_max_line_size);
               l_len        := NVL(LENGTH(l_message), 0);
            ELSE
               l_len    := 0;
            END IF;
--
         END LOOP;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         NULL;             -- Ignore errors... protect buffer overflow's etc.
   END print_output;

--
-- PRINT_OUTPUT
--
-- Displays content to DBMS_OUTPUT,  with optional display input parameter
--
   PROCEDURE print_output(
      p_display_bit   IN   NUMBER DEFAULT 0
    , p_message       IN   VARCHAR2
    , p_size          IN   NUMBER DEFAULT 250)
   IS
      c_process   CONSTANT VARCHAR2(100)   := 'PRINT_OUTPUT';
      l_message            VARCHAR2(32000);
      l_len                PLS_INTEGER;
      l_display_size       PLS_INTEGER     := NVL(p_size, 250);
      l_pos                PLS_INTEGER     := 0;
      l_max_line_size      PLS_INTEGER     := LEAST(l_display_size, 250);
   BEGIN
      IF NVL(p_display_bit, 0) = 1 THEN
--
         l_pos        := 1;
         l_message    := SUBSTR(p_message, l_pos, l_max_line_size);
         l_len        := NVL(LENGTH(l_message), 0);

--
         WHILE l_len > 0 LOOP
--
            DBMS_OUTPUT.put_line(SUBSTR(l_message, l_pos, l_max_line_size));

            IF l_display_size > l_max_line_size THEN
               l_pos        := l_pos + l_max_line_size;
               l_message    := SUBSTR(p_message, l_pos, l_max_line_size);
               l_len        := NVL(LENGTH(l_message), 0);
            ELSE
               l_len    := 0;
            END IF;
         END LOOP;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         NULL;             -- Ignore errors... protect buffer overflow's etc.
   END print_output;
END cs_print_utility; 
/

