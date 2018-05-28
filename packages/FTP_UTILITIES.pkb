CREATE OR REPLACE PACKAGE BODY hum_ftp_utilities
IS
--
-- CHANGE HISTORY
--
-- BCHASE        08-AUG-2006  
--                         Added exception handlers
--                         Added logic to verify and handle INTERFACE table instead of path
--                         for localpath entries
--
--
/* Display Output. Displays DBMS_OUTPUT in chunks so we don't bust the 255 limit by accident */
   PROCEDURE print_output (
      p_message                  IN       VARCHAR2 )
   IS
      c_process            CONSTANT VARCHAR2 ( 100 )
                                            := 'hum_ftp_UTILITIES.PRINT_OUTPUT';
   BEGIN
      dbms_output.put_line ( SUBSTR ( p_message
,                                     1
,                                     250 ));

      IF LENGTH ( p_message ) > 250
      THEN
         dbms_output.put_line ( SUBSTR ( p_message
,                                        251
,                                        250 ));
      END IF;

      IF LENGTH ( p_message ) > 501
      THEN
         dbms_output.put_line ( SUBSTR ( p_message
,                                        501
,                                        250 ));
      END IF;

      IF LENGTH ( p_message ) > 751
      THEN
         dbms_output.put_line ( SUBSTR ( p_message
,                                        751
,                                        250 ));
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;               -- Ignore errors... protect buffer overflow's etc.
   END print_output;


   PROCEDURE verify_server (
      errbuf                     OUT      VARCHAR2
,     retcode                    OUT      NUMBER
,     p_hostname                 IN       VARCHAR2
,     p_remotepath               IN       VARCHAR2
,     p_username                 IN       VARCHAR2
,     p_password                 IN       VARCHAR2
,     p_mainframe_connection     IN       VARCHAR2 DEFAULT 'F' )
   IS
      c_process            CONSTANT VARCHAR2 ( 100 )
                                         := 'hum_ftp_UTILITIES.VERIFY_SERVER';
      lbok                          BOOLEAN;
      p_error_msg                   VARCHAR2 ( 32000 );
      p_status                      VARCHAR2 ( 32000 );
      p_mainframe_conn              BOOLEAN;
      p_remote_path                 VARCHAR2 ( 2000 );
--
-- This applies to Oracle Applications Environments only
--
--      p_request_id                  NUMBER := fnd_global.conc_request_id;
--
   BEGIN
/* CLEAR PASSWORD SO IT CANNOT BE SEEN VIA CONCURRENT REQ VIEWS */
--
-- Change the argument identifiers to match your concurrent mgr setup
--
-- This applies to Oracle Applications Environments only
--
--      UPDATE fnd_concurrent_requests
--      SET argument4 = '*******'
--,         argument3 = '*******'
--,         argument_text =
--             REPLACE ( REPLACE ( argument_text
--,                                argument4
--,                                '*******' )
--,                      argument3
--,                      '*******' )
--      WHERE  request_id = p_request_id;
--
--      COMMIT;


      IF p_mainframe_connection = 'F'
      THEN
         p_mainframe_conn := FALSE;
         p_remote_path := p_remotepath;
      ELSE
         p_mainframe_conn := TRUE;
         p_remote_path := p_remotepath;
      END IF;

      print_output ( CHR ( 10 ) );

         IF p_mainframe_conn
         THEN
            print_output
                                      (    'REMOTE FTP SERVER (mainframe) :: '
                                        || p_hostname);
         ELSE
            print_output ( 'REMOTE FTP SERVER :: ' || p_hostname);
         END IF;

      print_output ( 'REMOTE PATH :: ' || p_remote_path);
      print_output ( CHR ( 10 ) );
--
      lbok :=
         hum_ftp_interface.verify_server
                                    ( p_remotepath =>                  p_remote_path
,                                     p_username =>                    p_username
,                                     p_password =>                    p_password
,                                     p_hostname =>                    p_hostname
,                                     v_status =>                      p_status
,                                     v_error_message =>               p_error_msg
,                                     p_port =>                        21
,                                     p_filetype =>                    'ASCII'
,                                     p_mainframe_connection =>        p_mainframe_conn );

      IF lbok AND NVL ( p_status, 'SUCCESS' ) = 'SUCCESS'
      THEN
         print_output ( CHR ( 10 ) );
         print_output (    'SERVER CONNECTION TO '
                                       || p_hostname
                                       || ' IS VALID.');
         errbuf := NULL;
         retcode := 0;
      ELSE
         print_output ( CHR ( 10 ));
         print_output (    'ERROR :: SERVER CONNECTION TO '
                                       || p_hostname
                                       || ' IS NOT VALID. '
                                       || CHR ( 10 )
                                       || CHR ( 10 )
                                       || p_error_msg);
         errbuf := NULL;
         retcode := 2;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         print_output ( CHR ( 10 ));
         print_output (    c_process
                                       || ' :: ERROR :: SERVER CONNECTION TO '
                                       || p_hostname
                                       || ' IS NOT VALID. '
                                       || CHR ( 10 )
                                       || CHR ( 10 )
                                       || SQLCODE
                                       || ' - '
                                       || SQLERRM);
         errbuf := NULL;
         retcode := 2;
   END verify_server;

   PROCEDURE get_remote_file (
      errbuf                     OUT      VARCHAR2
,     retcode                    OUT      NUMBER
,     p_hostname                 IN       VARCHAR2
,     p_localpath                IN       VARCHAR2
,     p_filename                 IN       VARCHAR2
,     p_remotepath               IN       VARCHAR2
,     p_username                 IN       VARCHAR2
,     p_password                 IN       VARCHAR2
,     p_filetype                 IN       VARCHAR2 DEFAULT 'ASCII'
,     p_mainframe                IN       VARCHAR2 DEFAULT 'F'
,     p_mainframe_command        IN       VARCHAR2 DEFAULT NULL)
   IS
      c_process            CONSTANT VARCHAR2 ( 100 )
                                       := 'hum_ftp_UTILITIES.GET_REMOTE_FILE';
      p_status                      VARCHAR2 ( 32000 );
      p_error_msg                   VARCHAR2 ( 32000 );
      p_elapsed_time                VARCHAR2 ( 100 );
      p_files                       VARCHAR2 ( 4000 );
      p_bytes_trans                 NUMBER;
      p_trans_start                 DATE;
      p_trans_end                   DATE;
      lbok                          BOOLEAN;
      p_failed                      CHAR ( 1 ) := 'N';
      p_mainframe_conn              BOOLEAN;
      p_remote_path                 VARCHAR2 ( 240 );
      p_exists                      BOOLEAN;
      p_block_size                  BINARY_INTEGER;
      l_original_filename           VARCHAR2 ( 4000 );
      l_new_filename                VARCHAR2 ( 4000 );
      l_success                     VARCHAR2 ( 32767 );
      l_dba_directory               VARCHAR2 ( 100 );
      l_interface                   VARCHAR2 ( 100 );
      err_dba_dir_not_defined       EXCEPTION;
      err_dzero_byte_file           EXCEPTION;
--
-- This applies to Oracle Applications Environments only
--
--      p_request_id                  NUMBER := fnd_global.conc_request_id;
--
   BEGIN
/* CLEAR PASSWORD SO IT CANNOT BE SEEN VIA CONCURRENT REQ VIEWS */
--
-- Change the argument identifiers to match your concurrent mgr setup
--
-- This applies to Oracle Applications Environments only
--
--      UPDATE fnd_concurrent_requests
--      SET argument4 = '*******'
--,         argument3 = '*******'
--,         argument_text =
--             REPLACE ( REPLACE ( argument_text
--,                                argument4
--,                                '*******' )
--,                      argument3
--,                      '*******' )
--      WHERE  request_id = p_request_id;
--
--      COMMIT;
--
-- l_interface is the name of the DBA_DIRECTORY that you wish to use for 
-- this operation. You must have READ/WRITE permissions to this dba_directory
--
      l_interface := UPPER ( p_localpath );

      BEGIN
         SELECT RTRIM ( directory_path, '/' )
         INTO   l_dba_directory
         FROM   dba_directories
         WHERE  directory_name = l_interface;
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            l_dba_directory := l_interface;
            RAISE err_dba_dir_not_defined;
      END;

      IF p_mainframe = 'F'
      THEN
         p_mainframe_conn := FALSE;
         p_remote_path := p_remotepath;
      ELSE
         p_mainframe_conn := TRUE;
         p_remote_path := p_remotepath;
      END IF;

      IF p_filetype NOT IN ( 'ASCII', 'BINARY' )
      THEN
         p_failed := 'Y';
         p_error_msg := 'INVALID FILETYPE DEFINED. MUST BE ASCII or BINARY.';
      END IF;

--
      IF p_failed = 'N'
      THEN

      print_output ( CHR ( 10 ) );

         IF p_mainframe_conn
         THEN
            print_output
                                      (    'REMOTE FTP SERVER (mainframe) :: '
                                        || p_hostname);
         ELSE
            print_output ( 'REMOTE FTP SERVER :: ' || p_hostname);
         END IF;

      print_output ( 'REMOTE PATH :: ' || p_remote_path);
      print_output ( 'LOCAL PATH :: ' || l_dba_directory);

      print_output ( CHR ( 10 ) );


         IF p_mainframe_conn
         THEN
            print_output (    'SITE COMMAND :: '
                                          || p_mainframe_command);
            print_output (    'FILENAME :: '
                                          || REPLACE ( p_filename
,                                                      '#'
,                                                      ' => ' ));
         ELSE
            print_output (    'FILENAME :: '
                                          || REPLACE ( p_filename
,                                                      '#'
,                                                      ' => ' ));
         END IF;

         print_output ( 'TRANSFER MODE :: ' || p_filetype);
         print_output ( CHR ( 10 ));
--
-- Lets setup our output header columns
--
-- To process a file as a different name use the # symbol
-- test.txt#test.txt20032801
-- Would be used if you wanted to get the file test.txt but copy to local server as test.txt20032801
         print_output (    RPAD ( 'FILENAME', 40 )
                                       || ' | '
                                       || RPAD ( 'STATUS', 15 )
                                       || ' | '
                                       || RPAD ( 'BYTES', 15 )
                                       || ' | '
                                       || RPAD ( 'START TIME', 25 )
                                       || ' | '
                                       || RPAD ( 'END TIME', 25 )
                                       || ' | '
                                       || 'ERROR MESSAGE');
         print_output ( CHR ( 10 ));
--
         p_files := p_filename;
         lbok :=
            hum_ftp_interface.get ( p_localpath =>                   l_interface
,                                   p_filename =>                    p_files
,                                   p_remotepath =>                  p_remote_path
,                                   p_username =>                    p_username
,                                   p_password =>                    p_password
,                                   p_hostname =>                    p_hostname
,                                   v_status =>                      p_status
,                                   v_error_message =>               p_error_msg
,                                   n_bytes_transmitted =>           p_bytes_trans
,                                   d_trans_start =>                 p_trans_start
,                                   d_trans_end =>                   p_trans_end
,                                   p_port =>                        21
,                                   p_filetype =>                    p_filetype
,                                   p_mainframe_ftp =>               p_mainframe_conn
,                                   p_mainframe_cmd =>               p_mainframe_command );

      IF lbok AND NVL ( p_status, 'SUCCESS' ) = 'SUCCESS'
         THEN
            IF NVL ( INSTR ( p_filename, '#' ), 0 ) = 0
            THEN
               l_new_filename := p_filename;
            ELSE
               l_new_filename :=
                  LTRIM ( RTRIM ( SUBSTR ( p_filename
,                                          INSTR ( p_filename, '#' ) + 1 )));
            END IF;

            /* Getting filesize from local path which will show the bytes successfully written */
            utl_file.fgetattr ( LOCATION =>                      l_interface
,                               filename =>                      l_new_filename
,                               fexists =>                       p_exists
,                               file_length =>                   p_bytes_trans
,                               block_size =>                    p_block_size );

            IF p_exists
-- If we don't see the file probably a permissions problem prevented the creation
            THEN
               IF p_bytes_trans = 0
               THEN
                  RAISE err_dzero_byte_file;
               END IF;

               print_output
                                    (    RPAD ( REPLACE ( p_filename
,                                                         '#'
,                                                         ' => ' )
,                                               40 )
                                      || ' | '
                                      || RPAD ( p_status, 15 )
                                      || ' | '
                                      || RPAD ( TO_CHAR ( p_bytes_trans ), 15 )
                                      || ' | '
                                      || RPAD ( TO_CHAR ( p_trans_start
,                                                         'YYYY-MM-DD HH:MI:SS' )
,                                               25 )
                                      || ' | '
                                      || RPAD ( TO_CHAR ( p_trans_end
,                                                         'YYYY-MM-DD HH:MI:SS' )
,                                               25 )
                                      || ' | '
                                      || p_error_msg);
            ELSE
               p_status := 'TRANSFER FAILED. FILE NOT CREATED.';
            END IF;

            IF p_status <> 'SUCCESS'
            THEN
               p_failed := 'Y';
            END IF;
         ELSE
            p_failed := 'Y';
         END IF;
      END IF;

      IF p_failed = 'N'
      THEN
         print_output ( CHR ( 10 ));
         print_output ( 'FTP PROCESS COMPLETED.');
         errbuf := NULL;
         retcode := 0;
      ELSE
         print_output ( CHR ( 10 ));
         print_output (    'ERROR :: FTP PROCESS FAILED :: '
                                       || p_error_msg);
         errbuf := NULL;
         retcode := 2;
      END IF;
   EXCEPTION
      WHEN err_dzero_byte_file
      THEN
         l_success :=
               'RETRIEVED FILE IS A ZERO-BYTE FILE OR DOES NOT EXIST ['
            || l_new_filename
            || ']';
         print_output ( CHR ( 10 ));
         print_output (    c_process
                                       || ' :: ERROR :: FTP PROCESS FAILED :: '
                                       || l_success);
         errbuf := NULL;
         retcode := 2;
      WHEN err_dba_dir_not_defined
      THEN
         l_success := 'DBA DIRECTORY NOT DEFINED [' || l_dba_directory || ']';
         print_output ( CHR ( 10 ));
         print_output (    c_process
                                       || ' :: ERROR :: FTP PROCESS FAILED :: '
                                       || l_success);
         errbuf := NULL;
         retcode := 2;
      WHEN OTHERS
      THEN
         print_output ( CHR ( 10 ));
         print_output (    c_process
                                       || ' :: ERROR :: FTP PROCESS FAILED :: '
                                       || SQLCODE
                                       || ' - '
                                       || SQLERRM
                                       || ' :: '
                                       || p_error_msg);
         errbuf := NULL;
         retcode := 2;
   END get_remote_file;

   PROCEDURE put_remote_file (
      errbuf                     OUT      VARCHAR2
,     retcode                    OUT      NUMBER
,     p_hostname                 IN       VARCHAR2
,     p_localpath                IN       VARCHAR2
,     p_filename                 IN       VARCHAR2
,     p_remotepath               IN       VARCHAR2
,     p_username                 IN       VARCHAR2
,     p_password                 IN       VARCHAR2
,     p_filetype                 IN       VARCHAR2 DEFAULT 'ASCII'
,     p_mainframe                IN       VARCHAR2 DEFAULT 'F'
,     p_mainframe_command        IN       VARCHAR2 DEFAULT NULL )
   IS
      c_process            CONSTANT VARCHAR2 ( 100 )
                                       := 'hum_ftp_UTILITIES.PUT_REMOTE_FILE';
      p_status                      VARCHAR2 ( 32000 );
      p_error_msg                   VARCHAR2 ( 32000 );
      p_elapsed_time                VARCHAR2 ( 100 );
      p_files                       VARCHAR2 ( 4000 );
      p_bytes_trans                 NUMBER;
      p_trans_start                 DATE;
      p_trans_end                   DATE;
      lbok                          BOOLEAN;
      p_failed                      CHAR ( 1 ) := 'N';
      p_mainframe_conn              BOOLEAN;
      p_remote_path                 VARCHAR2 ( 240 );
      p_exists                      BOOLEAN;
      p_block_size                  BINARY_INTEGER;
      l_original_filename           VARCHAR2 ( 4000 );
      l_new_filename                VARCHAR2 ( 4000 );
      l_success                     VARCHAR2 ( 32767 );
      l_dba_directory               VARCHAR2 ( 100 );
      l_interface                   VARCHAR2 ( 100 );
      err_dba_dir_not_defined       EXCEPTION;
      err_dzero_byte_file           EXCEPTION;
--
-- This applies to Oracle Applications Environments only
--
--      p_request_id                  NUMBER := fnd_global.conc_request_id;
--
   BEGIN
/* CLEAR PASSWORD SO IT CANNOT BE SEEN VIA CONCURRENT REQ VIEWS */
--
-- Change the argument identifiers to match your concurrent mgr setup
--
-- This applies to Oracle Applications Environments only
--
--      UPDATE fnd_concurrent_requests
--      SET argument4 = '*******'
--,         argument3 = '*******'
--,         argument_text =
--             REPLACE ( REPLACE ( argument_text
--,                                argument4
--,                                '*******' )
--,                      argument3
--,                      '*******' )
--      WHERE  request_id = p_request_id;
--
--      COMMIT;
--
-- l_interface is the name of the DBA_DIRECTORY that you wish to use for 
-- this operation. You must have READ/WRITE permissions to this dba_directory
--
      l_interface := UPPER ( p_localpath );


      BEGIN
         SELECT RTRIM ( directory_path, '/' )
         INTO   l_dba_directory
         FROM   dba_directories
         WHERE  directory_name = l_interface;
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            l_dba_directory := l_interface;
            RAISE err_dba_dir_not_defined;
      END;


      IF p_mainframe = 'F'
      THEN
         p_mainframe_conn := FALSE;
         p_remote_path := p_remotepath;
      ELSE
         p_mainframe_conn := TRUE;
         p_remote_path := p_remotepath;
      END IF;


      IF p_filetype NOT IN ( 'ASCII', 'BINARY' )
      THEN
         p_failed := 'Y';
         p_error_msg := 'INVALID FILETYPE DEFINED. MUST BE ASCII or BINARY.';
      END IF;

--
      IF p_failed = 'N'
      THEN
      print_output ( CHR ( 10 ) );

         IF p_mainframe_conn
         THEN
            print_output
                                      (    'REMOTE FTP SERVER (mainframe) :: '
                                        || p_hostname);
         ELSE
            print_output ( 'REMOTE FTP SERVER :: ' || p_hostname);
         END IF;

      print_output ( 'REMOTE PATH :: ' || p_remote_path);
      print_output ( 'LOCAL PATH :: ' || l_dba_directory);

      print_output ( CHR ( 10 ) );


         IF p_mainframe_conn
         THEN
            print_output (    'SITE COMMAND :: '
                                          || p_mainframe_command);
            print_output (    'FILENAME :: '
                                          || REPLACE ( p_filename
,                                                      '#'
,                                                      ' => ' ));
         ELSE
            print_output (    'FILENAME :: '
                                          || REPLACE ( p_filename
,                                                      '#'
,                                                      ' => ' ));
         END IF;

         print_output ( 'TRANSFER MODE :: ' || p_filetype);
         print_output ( CHR ( 10 ));

         IF NVL ( INSTR ( p_filename, '#' ), 0 ) = 0
         THEN
            l_original_filename := p_filename;
         ELSE
            l_original_filename :=
               LTRIM ( RTRIM ( SUBSTR ( p_filename
,                                       1
,                                       INSTR ( p_filename, '#' ) - 1 )));
         END IF;

         /* Check to see if file exists before we even start */
         utl_file.fgetattr ( LOCATION =>                      l_interface
,                            filename =>                      l_original_filename
,                            fexists =>                       p_exists
,                            file_length =>                   p_bytes_trans
,                            block_size =>                    p_block_size );

--
         IF NOT p_exists
         THEN
            p_failed := 'Y';
            p_error_msg :=
               l_dba_directory || '/' || l_original_filename
               || ' DOES NOT EXIST.';
         ELSE
            IF p_bytes_trans = 0
            THEN
               RAISE err_dzero_byte_file;
            END IF;

--
-- Lets setup our output header columns
--
-- To process a file as a different name use the # symbol
-- test.txt#test.txt20032801
-- Would be used if you wanted to get the file test.txt but copy to local server as test.txt20032801
            print_output (    RPAD ( 'FILENAME', 40 )
                                          || ' | '
                                          || RPAD ( 'STATUS', 15 )
                                          || ' | '
                                          || RPAD ( 'BYTES', 15 )
                                          || ' | '
                                          || RPAD ( 'START TIME', 25 )
                                          || ' | '
                                          || RPAD ( 'END TIME', 25 )
                                          || ' | '
                                          || 'ERROR MESSAGE');
            print_output ( CHR ( 10 ));
--
            p_files := p_filename;
            lbok :=
               hum_ftp_interface.put ( p_localpath =>                   l_interface
,                                      p_filename =>                    p_files
,                                      p_remotepath =>                  p_remote_path
,                                      p_username =>                    p_username
,                                      p_password =>                    p_password
,                                      p_hostname =>                    p_hostname
,                                      v_status =>                      p_status
,                                      v_error_message =>               p_error_msg
,                                      n_bytes_transmitted =>           p_bytes_trans
,                                      d_trans_start =>                 p_trans_start
,                                      d_trans_end =>                   p_trans_end
,                                      p_port =>                        21
,                                      p_filetype =>                    p_filetype
,                                      p_mainframe_ftp =>               p_mainframe_conn
,                                      p_mainframe_cmd =>               p_mainframe_command );

      IF lbok AND NVL ( p_status, 'SUCCESS' ) = 'SUCCESS'
            THEN
               print_output
                                   (    RPAD ( REPLACE ( p_filename
,                                                        '#'
,                                                        ' => ' )
,                                              40 )
                                     || ' | '
                                     || RPAD ( p_status, 15 )
                                     || ' | '
                                     || RPAD ( TO_CHAR ( p_bytes_trans ), 15 )
                                     || ' | '
                                     || RPAD ( TO_CHAR ( p_trans_start
,                                                        'YYYY-MM-DD HH:MI:SS' )
,                                              25 )
                                     || ' | '
                                     || RPAD ( TO_CHAR ( p_trans_end
,                                                        'YYYY-MM-DD HH:MI:SS' )
,                                              25 )
                                     || ' | '
                                     || p_error_msg);

               IF p_status <> 'SUCCESS'
               THEN
                  p_failed := 'Y';
               END IF;
            ELSE
               p_failed := 'Y';
            END IF;
         END IF;
      END IF;

      IF p_failed = 'N'
      THEN
         print_output ( CHR ( 10 ));
         print_output ( 'FTP PROCESS COMPLETED.');
         errbuf := NULL;
         retcode := 0;
      ELSE
         print_output ( CHR ( 10 ));
         print_output (    'ERROR :: FTP PROCESS FAILED :: '
                                       || p_error_msg);
         errbuf := NULL;
         retcode := 2;
      END IF;
   EXCEPTION
      WHEN err_dzero_byte_file
      THEN
         l_success :=
               'LOCAL FILE IS A ZERO-BYTE FILE OR DOES NOT EXIST ['
            || l_original_filename
            || ']';
         print_output ( CHR ( 10 ));
         print_output (    c_process
                                       || ' :: ERROR :: FTP PROCESS FAILED :: '
                                       || l_success);
         errbuf := NULL;
         retcode := 2;
      WHEN err_dba_dir_not_defined
      THEN
         l_success := 'DBA DIRECTORY NOT DEFINED [' || l_dba_directory || ']';
         print_output ( CHR ( 10 ));
         print_output (    c_process
                                       || ' :: ERROR :: FTP PROCESS FAILED :: '
                                       || l_success);
         errbuf := NULL;
         retcode := 2;
      WHEN OTHERS
      THEN
         print_output ( CHR ( 10 ));
         print_output (    c_process
                                       || ' :: ERROR :: FTP PROCESS FAILED :: '
                                       || SQLCODE
                                       || ' - '
                                       || SQLERRM
                                       || ' :: '
                                       || p_error_msg);
         errbuf := NULL;
         retcode := 2;
   END put_remote_file;

   PROCEDURE remove_remote_file (
      errbuf                     OUT      VARCHAR2
,     retcode                    OUT      NUMBER
,     p_hostname                 IN       VARCHAR2
,     p_filename                 IN       VARCHAR2
,     p_remotepath               IN       VARCHAR2
,     p_username                 IN       VARCHAR2
,     p_password                 IN       VARCHAR2
,     p_mainframe                IN       VARCHAR2 DEFAULT 'F' )
   IS
      c_process            CONSTANT VARCHAR2 ( 100 )
                                    := 'hum_ftp_UTILITIES.REMOTE_REMOTE_FILE';
      p_status                      VARCHAR2 ( 32000 );
      p_error_msg                   VARCHAR2 ( 32000 );
      p_elapsed_time                VARCHAR2 ( 100 );
      p_files                       VARCHAR2 ( 4000 );
      p_bytes_trans                 NUMBER;
      p_localpath                   CHAR ( 1 ) := '.';
      p_trans_start                 DATE;
      p_trans_end                   DATE;
      lbok                          BOOLEAN;
      p_failed                      CHAR ( 1 ) := 'N';
      p_mainframe_conn              BOOLEAN;
      p_remote_path                 VARCHAR2 ( 240 );
      p_exists                      BOOLEAN;
      p_block_size                  BINARY_INTEGER;
--
-- This applies to Oracle Applications Environments only
--
--      p_request_id                  NUMBER := fnd_global.conc_request_id;
--
   BEGIN
/* CLEAR PASSWORD SO IT CANNOT BE SEEN VIA CONCURRENT REQ VIEWS */
--
-- Change the argument identifiers to match your concurrent mgr setup
--
-- This applies to Oracle Applications Environments only
--
--      UPDATE fnd_concurrent_requests
--      SET argument4 = '*******'
--,         argument3 = '*******'
--,         argument_text =
--             REPLACE ( REPLACE ( argument_text
--,                                argument4
--,                                '*******' )
--,                      argument3
--,                      '*******' )
--      WHERE  request_id = p_request_id;
--
--      COMMIT;


      IF p_mainframe = 'F'
      THEN
         p_mainframe_conn := FALSE;
         p_remote_path := p_remotepath;
      ELSE
         p_mainframe_conn := TRUE;
         p_remote_path := p_remotepath;
      END IF;


--
      IF p_failed = 'N'
      THEN
      print_output ( CHR ( 10 ) );

         IF p_mainframe_conn
         THEN
            print_output
                                      (    'REMOTE FTP SERVER (mainframe) :: '
                                        || p_hostname);
         ELSE
            print_output ( 'REMOTE FTP SERVER :: ' || p_hostname);
         END IF;

      print_output ( 'REMOTE PATH :: ' || p_remote_path);
         print_output ( 'FILENAME :: ' || p_filename);
         print_output ( CHR ( 10 ));
--
-- Lets setup our output header columns
--
-- To process a file as a different name use the # symbol
-- test.txt#test.txt20032801
-- Would be used if you wanted to get the file test.txt but copy to local server as test.txt20032801
         print_output (    RPAD ( 'FILENAME', 40 )
                                       || ' | '
                                       || RPAD ( 'STATUS', 15 )
                                       || ' | '
                                       || RPAD ( 'BYTES', 15 )
                                       || ' | '
                                       || RPAD ( 'START TIME', 25 )
                                       || ' | '
                                       || RPAD ( 'END TIME', 25 )
                                       || ' | '
                                       || 'ERROR MESSAGE');
         print_output ( CHR ( 10 ));
--
         p_files := p_filename;
         lbok :=
            hum_ftp_interface.remove
                                    ( p_localpath =>                   p_localpath
,                                     p_filename =>                    p_files
,                                     p_remotepath =>                  p_remote_path
,                                     p_username =>                    p_username
,                                     p_password =>                    p_password
,                                     p_hostname =>                    p_hostname
,                                     v_status =>                      p_status
,                                     v_error_message =>               p_error_msg
,                                     n_bytes_transmitted =>           p_bytes_trans
,                                     d_trans_start =>                 p_trans_start
,                                     d_trans_end =>                   p_trans_end
,                                     p_port =>                        21
,                                     p_filetype =>                    'ASCII'
,                                     p_mainframe_connection =>        p_mainframe_conn );

      IF lbok AND NVL ( p_status, 'SUCCESS' ) = 'SUCCESS'
         THEN
            print_output
                                   (    RPAD ( p_filename, 40 )
                                     || ' | '
                                     || RPAD ( p_status, 15 )
                                     || ' | '
                                     || RPAD ( TO_CHAR ( p_bytes_trans ), 15 )
                                     || ' | '
                                     || RPAD ( TO_CHAR ( p_trans_start
,                                                        'YYYY-MM-DD HH:MI:SS' )
,                                              25 )
                                     || ' | '
                                     || RPAD ( TO_CHAR ( p_trans_end
,                                                        'YYYY-MM-DD HH:MI:SS' )
,                                              25 )
                                     || ' | '
                                     || p_error_msg);

            IF p_status <> 'SUCCESS'
            THEN
               p_failed := 'Y';
            END IF;
         ELSE
            p_failed := 'Y';
         END IF;
      END IF;

      IF p_failed = 'N'
      THEN
         print_output ( CHR ( 10 ));
         print_output ( 'FTP PROCESS COMPLETED.');
         errbuf := NULL;
         retcode := 0;
      ELSE
         print_output ( CHR ( 10 ));
         print_output (    'ERROR :: FTP PROCESS FAILED :: '
                                       || p_error_msg);
         errbuf := NULL;
         retcode := 2;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         print_output ( CHR ( 10 ));
         print_output (    c_process
                                       || ' :: ERROR :: FTP PROCESS FAILED :: '
                                       || SQLCODE
                                       || ' - '
                                       || SQLERRM
                                       || ' :: '
                                       || p_error_msg);
         errbuf := NULL;
         retcode := 2;
   END remove_remote_file;

   PROCEDURE rename_remote_file (
      errbuf                     OUT      VARCHAR2
,     retcode                    OUT      NUMBER
,     p_hostname                 IN       VARCHAR2
,     p_filename                 IN       VARCHAR2
,     p_remotepath               IN       VARCHAR2
,     p_username                 IN       VARCHAR2
,     p_password                 IN       VARCHAR2
,     p_mainframe                IN       VARCHAR2 DEFAULT 'F' )
   IS
      c_process            CONSTANT VARCHAR2 ( 100 )
                                    := 'hum_ftp_UTILITIES.RENAME_REMOTE_FILE';
      p_status                      VARCHAR2 ( 32000 );
      p_error_msg                   VARCHAR2 ( 32000 );
      p_elapsed_time                VARCHAR2 ( 100 );
      p_files                       VARCHAR2 ( 4000 );
      p_bytes_trans                 NUMBER;
      p_localpath                   CHAR ( 1 ) := '.';
      p_trans_start                 DATE;
      p_trans_end                   DATE;
      lbok                          BOOLEAN;
      p_failed                      CHAR ( 1 ) := 'N';
      p_mainframe_conn              BOOLEAN;
      p_remote_path                 VARCHAR2 ( 240 );
      p_exists                      BOOLEAN;
      p_block_size                  BINARY_INTEGER;
--
-- This applies to Oracle Applications Environments only
--
--      p_request_id                  NUMBER := fnd_global.conc_request_id;
--
   BEGIN
/* CLEAR PASSWORD SO IT CANNOT BE SEEN VIA CONCURRENT REQ VIEWS */
--
-- Change the argument identifiers to match your concurrent mgr setup
--
-- This applies to Oracle Applications Environments only
--
--      UPDATE fnd_concurrent_requests
--      SET argument4 = '*******'
--,         argument3 = '*******'
--,         argument_text =
--             REPLACE ( REPLACE ( argument_text
--,                                argument4
--,                                '*******' )
--,                      argument3
--,                      '*******' )
--      WHERE  request_id = p_request_id;
--
--      COMMIT;

   

      IF p_mainframe = 'F'
      THEN
         p_mainframe_conn := FALSE;
         p_remote_path := p_remotepath;
      ELSE
         p_mainframe_conn := TRUE;
         p_remote_path := p_remotepath;
      END IF;


--
      IF p_failed = 'N'
      THEN
      print_output ( CHR ( 10 ) );

         IF p_mainframe_conn
         THEN
            print_output
                                      (    'REMOTE FTP SERVER (mainframe) :: '
                                        || p_hostname);
         ELSE
            print_output ( 'REMOTE FTP SERVER :: ' || p_hostname);
         END IF;

      print_output ( 'REMOTE PATH :: ' || p_remote_path);
         print_output (    'FILENAME :: '
                                       || REPLACE ( p_filename
,                                                   '#'
,                                                   ' => ' ));
         print_output ( CHR ( 10 ));
--
-- Lets setup our output header columns
--
-- To process a file as a different name use the # symbol
-- test.txt#test.txt20032801
-- Would be used if you wanted to get the file test.txt but copy to local server as test.txt20032801
         print_output (    RPAD ( 'FILENAME', 40 )
                                       || ' | '
                                       || RPAD ( 'STATUS', 15 )
                                       || ' | '
                                       || RPAD ( 'BYTES', 15 )
                                       || ' | '
                                       || RPAD ( 'START TIME', 25 )
                                       || ' | '
                                       || RPAD ( 'END TIME', 25 )
                                       || ' | '
                                       || 'ERROR MESSAGE');
         print_output ( CHR ( 10 ));
--
         p_files := p_filename;
         lbok :=
            hum_ftp_interface.RENAME
                                    ( p_localpath =>                   p_localpath
,                                     p_filename =>                    p_files
,                                     p_remotepath =>                  p_remote_path
,                                     p_username =>                    p_username
,                                     p_password =>                    p_password
,                                     p_hostname =>                    p_hostname
,                                     v_status =>                      p_status
,                                     v_error_message =>               p_error_msg
,                                     n_bytes_transmitted =>           p_bytes_trans
,                                     d_trans_start =>                 p_trans_start
,                                     d_trans_end =>                   p_trans_end
,                                     p_port =>                        21
,                                     p_filetype =>                    'ASCII'
,                                     p_mainframe_connection =>        p_mainframe_conn );

      IF lbok AND NVL ( p_status, 'SUCCESS' ) = 'SUCCESS'
         THEN
            print_output
                                   (    RPAD ( REPLACE ( p_filename
,                                                        '#'
,                                                        ' => ' )
,                                              40 )
                                     || ' | '
                                     || RPAD ( p_status, 15 )
                                     || ' | '
                                     || RPAD ( TO_CHAR ( p_bytes_trans ), 15 )
                                     || ' | '
                                     || RPAD ( TO_CHAR ( p_trans_start
,                                                        'YYYY-MM-DD HH:MI:SS' )
,                                              25 )
                                     || ' | '
                                     || RPAD ( TO_CHAR ( p_trans_end
,                                                        'YYYY-MM-DD HH:MI:SS' )
,                                              25 )
                                     || ' | '
                                     || p_error_msg);

            IF p_status <> 'SUCCESS'
            THEN
               p_failed := 'Y';
            END IF;
         ELSE
            p_failed := 'Y';
         END IF;
      END IF;

      IF p_failed = 'N'
      THEN
         print_output ( CHR ( 10 ));
         print_output ( 'FTP PROCESS COMPLETED.');
         errbuf := NULL;
         retcode := 0;
      ELSE
         print_output ( CHR ( 10 ));
         print_output (    'ERROR :: FTP PROCESS FAILED :: '
                                       || p_error_msg);
         errbuf := NULL;
         retcode := 2;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         print_output ( CHR ( 10 ));
         print_output (    c_process
                                       || ' :: ERROR :: FTP PROCESS FAILED :: '
                                       || SQLCODE
                                       || ' - '
                                       || SQLERRM
                                       || ' :: '
                                       || p_error_msg);

         errbuf := NULL;
         retcode := 2;
   END rename_remote_file;

/* USE THIS PROCEDURE TO COLLECT A DIRECTORY LISTING */
/* OF REMOTE SERVER TO A FILE ON THE LOCAL DATABASE SERVER */
/* LOCAL DIRECTORY MUST BE WRITABLE BY UTL_FILE ROUTINES */
--
-- Only return filenames
--

   PROCEDURE get_remote_dir_short (
      errbuf                     OUT      VARCHAR2
,     retcode                    OUT      NUMBER
,     p_hostname                 IN       VARCHAR2
,     p_localpath                IN       VARCHAR2
,     p_filename_filter          IN       VARCHAR2 DEFAULT NULL
,     p_dir_filename             IN       VARCHAR2 DEFAULT 'remotedir_list.txt'
,     p_remotepath               IN       VARCHAR2
,     p_username                 IN       VARCHAR2
,     p_password                 IN       VARCHAR2
,     p_mainframe                IN       VARCHAR2 DEFAULT 'F' )
   IS
      c_process            CONSTANT VARCHAR2 ( 100 )
                                        := 'hum_ftp_UTILITIES.GET_REMOTE_DIR_SHORT';
      u_filehandle                  utl_file.file_type;
      l_buffer                      VARCHAR2 ( 32000 );
      p_status                      VARCHAR2 ( 32000 );
      p_error_msg                   VARCHAR2 ( 32000 );
      p_elapsed_time                VARCHAR2 ( 100 );
      p_files                       VARCHAR2 ( 4000 );
      p_bytes_trans                 NUMBER;
      p_trans_start                 DATE;
      p_trans_end                   DATE;
      lbok                          BOOLEAN;
      p_failed                      CHAR ( 1 ) := 'N';
      p_mainframe_conn              BOOLEAN;
      p_remote_path                 VARCHAR2 ( 240 );
      p_exists                      BOOLEAN;
      p_block_size                  BINARY_INTEGER;
      l_filename_filter             VARCHAR2 ( 1000 );
      l_dir_filename                VARCHAR2 ( 1000 );
      l_success                     VARCHAR2 ( 32767 );
      l_dba_directory               VARCHAR2 ( 100 );
      l_interface                   VARCHAR2 ( 100 );
      err_dba_dir_not_defined       EXCEPTION;
      err_dzero_byte_file           EXCEPTION;
--
-- This applies to Oracle Applications Environments only
--
--      p_request_id                  NUMBER := fnd_global.conc_request_id;
--
   BEGIN
/* CLEAR PASSWORD SO IT CANNOT BE SEEN VIA CONCURRENT REQ VIEWS */
--
-- Change the argument identifiers to match your concurrent mgr setup
--
-- This applies to Oracle Applications Environments only
--
--      UPDATE fnd_concurrent_requests
--      SET argument4 = '*******'
--,         argument3 = '*******'
--,         argument_text =
--             REPLACE ( REPLACE ( argument_text
--,                                argument4
--,                                '*******' )
--,                      argument3
--,                      '*******' )
--      WHERE  request_id = p_request_id;
--
--      COMMIT;
--
-- l_interface is the name of the DBA_DIRECTORY that you wish to use for 
-- this operation. You must have READ/WRITE permissions to this dba_directory
--
      l_interface := UPPER ( p_localpath );


      BEGIN
         SELECT RTRIM ( directory_path, '/' )
         INTO   l_dba_directory
         FROM   dba_directories
         WHERE  directory_name = l_interface;
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            l_dba_directory := l_interface;
            RAISE err_dba_dir_not_defined;
      END;

 

      IF p_mainframe = 'F'
      THEN
         p_mainframe_conn := FALSE;
         p_remote_path := p_remotepath;
      ELSE
         p_mainframe_conn := TRUE;
         p_remote_path := p_remotepath;
      END IF;

--
      IF p_failed = 'N'
      THEN
      print_output ( CHR ( 10 ) );

         IF p_mainframe_conn
         THEN
            print_output
                                      (    'REMOTE FTP SERVER (mainframe) :: '
                                        || p_hostname);
         ELSE
            print_output ( 'REMOTE FTP SERVER :: ' || p_hostname);
         END IF;

      print_output ( 'REMOTE PATH :: ' || p_remote_path);
      print_output ( 'LOCAL PATH :: ' || l_dba_directory);

      print_output ( CHR ( 10 ) );

         IF LTRIM ( RTRIM ( p_dir_filename )) IS NULL
         THEN
            l_dir_filename := 'remotedir_list.txt';
         ELSE
            l_dir_filename := LTRIM ( RTRIM ( p_dir_filename ));
         END IF;

         IF LTRIM ( RTRIM ( p_filename_filter )) IS NULL
         THEN
            l_filename_filter := '*';
         ELSE
            l_filename_filter := LTRIM ( RTRIM ( p_filename_filter ));
         END IF;

         print_output (    'DIRECTORY LISTING FILENAME :: '
                                       || l_dir_filename);
         print_output ( 'FILENAME FILTER :: '
                                       || l_filename_filter);
         print_output ( 'TRANSFER MODE :: ASCII');
         print_output ( CHR ( 10 ));
--
-- Lets setup our output header columns
--
         print_output (    RPAD ( 'DIRECTORY LISTING FILE', 40 )
                                       || ' | '
                                       || RPAD ( 'STATUS', 15 )
                                       || ' | '
                                       || RPAD ( 'BYTES', 15 )
                                       || ' | '
                                       || RPAD ( 'START TIME', 25 )
                                       || ' | '
                                       || RPAD ( 'END TIME', 25 )
                                       || ' | '
                                       || 'ERROR MESSAGE');
         print_output ( CHR ( 10 ));
--
         lbok :=
            hum_ftp_interface.ls ( p_localpath =>                   l_interface
,                                  p_filename_filter =>             l_filename_filter
,                                  p_dir_filename =>                l_dir_filename
,                                  p_remotepath =>                  p_remote_path
,                                  p_username =>                    p_username
,                                  p_password =>                    p_password
,                                  p_hostname =>                    p_hostname
,                                  v_status =>                      p_status
,                                  v_error_message =>               p_error_msg
,                                  n_bytes_transmitted =>           p_bytes_trans
,                                  d_trans_start =>                 p_trans_start
,                                  d_trans_end =>                   p_trans_end
,                                  p_port =>                        21
,                                  p_filetype =>                    'ASCII'
,                                  p_mainframe_ftp =>               p_mainframe_conn );

      IF lbok AND NVL ( p_status, 'SUCCESS' ) = 'SUCCESS'
         THEN
            /* Getting filesize from local path which will show the bytes successfully written */
            utl_file.fgetattr ( LOCATION =>                      l_interface
,                               filename =>                      l_dir_filename
,                               fexists =>                       p_exists
,                               file_length =>                   p_bytes_trans
,                               block_size =>                    p_block_size );

            IF p_exists
-- If we don't see the file probably a permissions problem prevented the creation
            THEN
               IF p_bytes_trans = 0
               THEN
                  RAISE err_dzero_byte_file;
               END IF;

               print_output
                                    (    RPAD ( l_dir_filename, 40 )
                                      || ' | '
                                      || RPAD ( p_status, 15 )
                                      || ' | '
                                      || RPAD ( TO_CHAR ( p_bytes_trans ), 15 )
                                      || ' | '
                                      || RPAD ( TO_CHAR ( p_trans_start
,                                                         'YYYY-MM-DD HH:MI:SS' )
,                                               25 )
                                      || ' | '
                                      || RPAD ( TO_CHAR ( p_trans_end
,                                                         'YYYY-MM-DD HH:MI:SS' )
,                                               25 )
                                      || ' | '
                                      || p_error_msg);
            ELSE
               p_status := 'TRANSFER FAILED. FILE NOT CREATED.';
            END IF;

            IF p_status <> 'SUCCESS'
            THEN
               p_failed := 'Y';
            END IF;
         ELSE
            p_failed := 'Y';
         END IF;
      END IF;

      IF p_failed = 'N'
      THEN
         print_output ( CHR ( 10 ));
         print_output ( 'Directory Listing Details :: ');
         print_output ( CHR ( 10 ));
--
         u_filehandle :=
                      utl_file.fopen ( l_interface
,                                      l_dir_filename
,                                      'r'
,                                      32000 );

         LOOP
            BEGIN
               utl_file.get_line ( u_filehandle, l_buffer );
               print_output ( l_buffer);

            EXCEPTION
               WHEN NO_DATA_FOUND
               THEN
                  EXIT;
            END;
         END LOOP;

         print_output ( CHR ( 10 ));
         print_output ( CHR ( 10 ));
         print_output ( 'FTP PROCESS COMPLETED.');
         errbuf := NULL;
         retcode := 0;
      ELSE
         print_output ( CHR ( 10 ));
         print_output (    'ERROR :: FTP PROCESS FAILED :: '
                                       || p_error_msg);
         errbuf := NULL;
         retcode := 2;
      END IF;
   EXCEPTION
      WHEN err_dzero_byte_file
      THEN
         l_success :=
               'RETRIEVED DIRECTORY FILE IS A ZERO-BYTE FILE OR DOES NOT EXIST ['
            || l_dir_filename
            || ']';
         print_output ( CHR ( 10 ));
         print_output (    c_process
                                       || ' :: ERROR :: FTP PROCESS FAILED :: '
                                       || l_success);
         errbuf := NULL;
         retcode := 2;
      WHEN err_dba_dir_not_defined
      THEN
         l_success := 'DBA DIRECTORY NOT DEFINED [' || l_dba_directory || ']';
         print_output ( CHR ( 10 ));
         print_output (    c_process
                                       || ' :: ERROR :: FTP PROCESS FAILED :: '
                                       || l_success);
         errbuf := NULL;
         retcode := 2;
      WHEN OTHERS
      THEN
         print_output ( CHR ( 10 ));
         print_output (    c_process
                                       || ' :: ERROR :: FTP PROCESS FAILED :: '
                                       || SQLCODE
                                       || ' - '
                                       || SQLERRM
                                       || ' :: '
                                       || p_error_msg);
         errbuf := NULL;
         retcode := 2;
   END get_remote_dir_short;

/* USE THIS PROCEDURE TO COLLECT A DIRECTORY LISTING */
/* OF REMOTE SERVER TO A FILE ON THE LOCAL DATABASE SERVER */
/* LOCAL DIRECTORY MUST BE WRITABLE BY UTL_FILE ROUTINES */
--
-- Returns full detail (timestamps,permissions, filenames, filesizes,etc)
--

   PROCEDURE get_remote_dir_long (
      errbuf                     OUT      VARCHAR2
,     retcode                    OUT      NUMBER
,     p_hostname                 IN       VARCHAR2
,     p_localpath                IN       VARCHAR2
,     p_filename_filter          IN       VARCHAR2 DEFAULT NULL
,     p_dir_filename             IN       VARCHAR2 DEFAULT 'remotedir_list.txt'
,     p_remotepath               IN       VARCHAR2
,     p_username                 IN       VARCHAR2
,     p_password                 IN       VARCHAR2
,     p_mainframe                IN       VARCHAR2 DEFAULT 'F' )
   IS
      c_process            CONSTANT VARCHAR2 ( 100 )
                                        := 'hum_ftp_UTILITIES.GET_REMOTE_DIR_LONG';
      u_filehandle                  utl_file.file_type;
      l_buffer                      VARCHAR2 ( 32000 );
      p_status                      VARCHAR2 ( 32000 );
      p_error_msg                   VARCHAR2 ( 32000 );
      p_elapsed_time                VARCHAR2 ( 100 );
      p_files                       VARCHAR2 ( 4000 );
      p_bytes_trans                 NUMBER;
      p_trans_start                 DATE;
      p_trans_end                   DATE;
      lbok                          BOOLEAN;
      p_failed                      CHAR ( 1 ) := 'N';
      p_mainframe_conn              BOOLEAN;
      p_remote_path                 VARCHAR2 ( 240 );
      p_exists                      BOOLEAN;
      p_block_size                  BINARY_INTEGER;
      l_filename_filter             VARCHAR2 ( 1000 );
      l_dir_filename                VARCHAR2 ( 1000 );
      l_success                     VARCHAR2 ( 32767 );
      l_dba_directory               VARCHAR2 ( 100 );
      l_interface                   VARCHAR2 ( 100 );
      err_dba_dir_not_defined       EXCEPTION;
      err_dzero_byte_file           EXCEPTION;
--
-- This applies to Oracle Applications Environments only
--
--      p_request_id                  NUMBER := fnd_global.conc_request_id;
--
   BEGIN
/* CLEAR PASSWORD SO IT CANNOT BE SEEN VIA CONCURRENT REQ VIEWS */
--
-- Change the argument identifiers to match your concurrent mgr setup
--
-- This applies to Oracle Applications Environments only
--
--      UPDATE fnd_concurrent_requests
--      SET argument4 = '*******'
--,         argument3 = '*******'
--,         argument_text =
--             REPLACE ( REPLACE ( argument_text
--,                                argument4
--,                                '*******' )
--,                      argument3
--,                      '*******' )
--      WHERE  request_id = p_request_id;
--
--      COMMIT;
--
-- l_interface is the name of the DBA_DIRECTORY that you wish to use for 
-- this operation. You must have READ/WRITE permissions to this dba_directory
--
      l_interface := UPPER ( p_localpath );


      BEGIN
         SELECT RTRIM ( directory_path, '/' )
         INTO   l_dba_directory
         FROM   dba_directories
         WHERE  directory_name = l_interface;
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            l_dba_directory := l_interface;
            RAISE err_dba_dir_not_defined;
      END;


      IF p_mainframe = 'F'
      THEN
         p_mainframe_conn := FALSE;
         p_remote_path := p_remotepath;
      ELSE
         p_mainframe_conn := TRUE;
         p_remote_path := p_remotepath;
      END IF;

--
      IF p_failed = 'N'
      THEN
      print_output ( CHR ( 10 ) );

         IF p_mainframe_conn
         THEN
            print_output
                                      (    'REMOTE FTP SERVER (mainframe) :: '
                                        || p_hostname);
         ELSE
            print_output ( 'REMOTE FTP SERVER :: ' || p_hostname);
         END IF;

      print_output ( 'REMOTE PATH :: ' || p_remote_path);
      print_output ( 'LOCAL PATH :: ' || l_dba_directory);

      print_output ( CHR ( 10 ) );

         IF LTRIM ( RTRIM ( p_dir_filename )) IS NULL
         THEN
            l_dir_filename := 'remotedir_list.txt';
         ELSE
            l_dir_filename := LTRIM ( RTRIM ( p_dir_filename ));
         END IF;

         IF LTRIM ( RTRIM ( p_filename_filter )) IS NULL
         THEN
            l_filename_filter := '*';
         ELSE
            l_filename_filter := LTRIM ( RTRIM ( p_filename_filter ));
         END IF;

         print_output (    'DIRECTORY LISTING FILENAME :: '
                                       || l_dir_filename);
         print_output ( 'FILENAME FILTER :: '
                                       || l_filename_filter);
         print_output ( 'TRANSFER MODE :: ASCII');
         print_output ( CHR ( 10 ));
--
-- Lets setup our output header columns
--
         print_output (    RPAD ( 'DIRECTORY LISTING FILE', 40 )
                                       || ' | '
                                       || RPAD ( 'STATUS', 15 )
                                       || ' | '
                                       || RPAD ( 'BYTES', 15 )
                                       || ' | '
                                       || RPAD ( 'START TIME', 25 )
                                       || ' | '
                                       || RPAD ( 'END TIME', 25 )
                                       || ' | '
                                       || 'ERROR MESSAGE');
         print_output ( CHR ( 10 ));
--
         lbok :=
            hum_ftp_interface.dir ( p_localpath =>                   l_interface
,                                   p_filename_filter =>             l_filename_filter
,                                   p_dir_filename =>                l_dir_filename
,                                   p_remotepath =>                  p_remote_path
,                                   p_username =>                    p_username
,                                   p_password =>                    p_password
,                                   p_hostname =>                    p_hostname
,                                   v_status =>                      p_status
,                                   v_error_message =>               p_error_msg
,                                   n_bytes_transmitted =>           p_bytes_trans
,                                   d_trans_start =>                 p_trans_start
,                                   d_trans_end =>                   p_trans_end
,                                   p_port =>                        21
,                                   p_filetype =>                    'ASCII'
,                                   p_mainframe_ftp =>               p_mainframe_conn );

      IF lbok AND NVL ( p_status, 'SUCCESS' ) = 'SUCCESS'
         THEN
            /* Getting filesize from local path which will show the bytes successfully written */
            utl_file.fgetattr ( LOCATION =>                      l_interface
,                               filename =>                      l_dir_filename
,                               fexists =>                       p_exists
,                               file_length =>                   p_bytes_trans
,                               block_size =>                    p_block_size );

            IF p_exists
-- If we don't see the file probably a permissions problem prevented the creation
            THEN
               IF p_bytes_trans = 0
               THEN
                  RAISE err_dzero_byte_file;
               END IF;

               print_output
                                    (    RPAD ( l_dir_filename, 40 )
                                      || ' | '
                                      || RPAD ( p_status, 15 )
                                      || ' | '
                                      || RPAD ( TO_CHAR ( p_bytes_trans ), 15 )
                                      || ' | '
                                      || RPAD ( TO_CHAR ( p_trans_start
,                                                         'YYYY-MM-DD HH:MI:SS' )
,                                               25 )
                                      || ' | '
                                      || RPAD ( TO_CHAR ( p_trans_end
,                                                         'YYYY-MM-DD HH:MI:SS' )
,                                               25 )
                                      || ' | '
                                      || p_error_msg);
            ELSE
               p_status := 'TRANSFER FAILED. FILE NOT CREATED.';
            END IF;

            IF p_status <> 'SUCCESS'
            THEN
               p_failed := 'Y';
            END IF;
         ELSE
            p_failed := 'Y';
         END IF;
      END IF;

      IF p_failed = 'N'
      THEN
         print_output ( CHR ( 10 ));
         print_output ( 'Directory Listing Details :: ');
         print_output ( CHR ( 10 ));
--
         u_filehandle :=
                      utl_file.fopen ( l_interface
,                                      l_dir_filename
,                                      'r'
,                                      32000 );

         LOOP
            BEGIN
               utl_file.get_line ( u_filehandle, l_buffer );
               print_output ( l_buffer);
            EXCEPTION
               WHEN NO_DATA_FOUND
               THEN
                  EXIT;
            END;
         END LOOP;

         print_output ( CHR ( 10 ));
         print_output ( CHR ( 10 ));
         print_output ( 'FTP PROCESS COMPLETED.');
         errbuf := NULL;
         retcode := 0;
      ELSE
         print_output ( CHR ( 10 ));
         print_output (    'ERROR :: FTP PROCESS FAILED :: '
                                       || p_error_msg);
         errbuf := NULL;
         retcode := 2;
      END IF;
   EXCEPTION
      WHEN err_dzero_byte_file
      THEN
         l_success :=
               'RETRIEVED DIRECTORY FILE IS A ZERO-BYTE FILE OR DOES NOT EXIST ['
            || l_dir_filename
            || ']';
         print_output ( CHR ( 10 ));
         print_output (    c_process
                                       || ' :: ERROR :: FTP PROCESS FAILED :: '
                                       || l_success);
         errbuf := NULL;
         retcode := 2;
      WHEN err_dba_dir_not_defined
      THEN
         l_success := 'DBA DIRECTORY NOT DEFINED [' || l_dba_directory || ']';
         print_output ( CHR ( 10 ));
         print_output (    c_process
                                       || ' :: ERROR :: FTP PROCESS FAILED :: '
                                       || l_success);
         errbuf := NULL;
         retcode := 2;
      WHEN OTHERS
      THEN
         print_output ( CHR ( 10 ));
         print_output (    c_process
                                       || ' :: ERROR :: FTP PROCESS FAILED :: '
                                       || SQLCODE
                                       || ' - '
                                       || SQLERRM
                                       || ' :: '
                                       || p_error_msg);
         errbuf := NULL;
         retcode := 2;
   END get_remote_dir_long;

/* Use this routine to return a failure code if not in production */
/* This would be used as a first stage in a request set to ensure */
/* a request set that includes the above FTP routines, that it    */
/* it would not fire off if executed in a test instance.          */
/*                                                                */
/* It would require someone to skip the first step to make it the */
/* request set run. However, in that event, they need to change   */
/* the necessary parameters to control the correct user/password  */
/* and server/path information                                    */
/*       										*/
/* We have a custom package and table that we use to identify     */
/* Production/QA/Test Instances. This data is used by shell       */
/* scripts, PLSQL, etc. to alter behavior with respect to the     */
/* Oracle environment. It ensures that we do not launch processes */
/* in non-production environments, or if we wish them to launch   */
/* how they launch (email addresses used, ftp servers used etc.)  */
/* can be controlled. You could easily build something similar    */
/*                                                         
   PROCEDURE is_not_prod (
      errbuf                     OUT      VARCHAR2
,     retcode                    OUT      NUMBER )
   IS
      c_process            CONSTANT VARCHAR2 ( 100 )
                                           := 'hum_ftp_UTILITIES.IS_NOT_PROD';
      l_step                        VARCHAR2 ( 1000 );
   BEGIN
      l_step := c_process || ' :: Executing HUM_MACHINE_INFO.IS_PROD ';

--
-- We built a table that has instances referenced in it with an instance type 
-- identifier to indicate usage. We then built a function that checked the type
-- for current oracle instance... it returned a yes or no if it was identified
-- as a production environment.
--
-- Although not included in this document set, it would be easy enough
-- for someone to add back in.
--
--      IF hum_machine_info.is_prod ( p_database ) = 'Y'
--      THEN
--         l_step := c_process || ' :: PRODUCTION ENVIRONMENT DETECTED ';
--         print_output ( l_step);
--         errbuf := NULL;
--         retcode := 0;
--      ELSE
--         l_step := c_process || ' :: NON-PRODUCTION ENVIRONMENT DETECTED ';
--         print_output ( l_step);
--         errbuf := NULL;
--         retcode := 2;
--      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         print_output (    c_process
                                       || ' :: ERROR :: '
                                       || l_step
                                       || ' :: '
                                       || SQLCODE
                                       || ' - '
                                       || SQLERRM);
         errbuf := NULL;
         retcode := 2;
   END is_not_prod;
*/

END hum_ftp_utilities;
/
