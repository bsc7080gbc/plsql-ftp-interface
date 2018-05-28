SET linesize 2000

DECLARE
   p_status         VARCHAR2(32000);
   p_error_msg      VARCHAR2(32000);
   p_elapsed_time   VARCHAR2(100);
   p_remote_path    VARCHAR2(2000);
   p_local_path     VARCHAR2(2000);
   p_hostname       VARCHAR2(100);
   p_username       VARCHAR2(100);
   p_password       VARCHAR2(100);
   p_files          VARCHAR2(4000);
   p_bytes_trans    NUMBER;
   p_trans_start    DATE;
   p_trans_end      DATE;
   lbok             BOOLEAN;
   lnfilescnt       NUMBER          := 0;
   l_errbuf         VARCHAR2(2000);
   l_retcode        PLS_INTEGER     := 0;
   p_failed         CHAR(1)         := 'N';
   p_database       VARCHAR2(10);
BEGIN
--
-- We turn on debug flag so as to display testing messages
--
   hum_ftp_interface.l_ftp_debug    := 'Y';
--
-- If we use the cs_print_utility, then use the following debug flag instead
--
--   cs_print_utility.g_debug_flag    := 'Y';
--
   lbok                             :=
      hum_ftp_interface.verify_server(p_remotepath =>                '<absolutepath>'
                                    , p_username =>                  '<username>'
                                    , p_password =>                  '<userpassword>'
                                    , p_hostname =>                  '<remoteserver>'
                                    , v_status =>                    p_status
                                    , v_error_message =>             p_error_msg
                                    , p_port =>                      21
                                    , p_filetype =>                  'ASCII'
                                    , p_mainframe_connection =>      FALSE);

--
   IF NOT lbok THEN
      DBMS_OUTPUT.put_line
                     ('FAILED. SERVER AND/OR PATH IS INVALID OR UNAVAILABLE.');
   ELSE
      DBMS_OUTPUT.put_line('PASS. SERVER AND PATH IS VALID AND AVAILABLE.');
   END IF;

--
   hum_ftp_utilities.get_remote_dir_long
                                      (errbuf =>                 l_errbuf
                                     , retcode =>                l_retcode
                                     , p_hostname =>             '<remoteserver>'
                                     , p_localpath =>            '<dba_directory_name>'
                                     , p_filename_filter =>      '*test*'
                                     , p_dir_filename =>         'remotedir_list.txt'
                                     , p_remotepath =>           '<absolutepath>'
                                     , p_username =>             '<username>'
                                     , p_password =>             '<userpassword>'
                                     , p_mainframe =>            'F');
--
-- Test mainframe
--
   hum_ftp_utilities.get_remote_dir_short
                                      (errbuf =>                 l_errbuf
                                     , retcode =>                l_retcode
                                     , p_hostname =>             '<remoteserver>'
                                     , p_localpath =>            '<dba_directory_name>'
                                     , p_filename_filter =>      '*DIR*'
                                     , p_dir_filename =>         'remotedir_list.txt'
                                     , p_remotepath =>           '.'
                                     , p_username =>             '<username>'
                                     , p_password =>             'Han$3826'
                                     , p_mainframe =>            'T');
--
   hum_ftp_utilities.get_remote_file(errbuf =>                   l_errbuf
                                   , retcode =>                  l_retcode
                                   , p_hostname =>               '<remoteserver>'
                                   , p_localpath =>              '<dba_directory_name>'
                                   , p_filename =>               'test1.doc#test2.doc'
                                   , p_remotepath =>             '<absolutepath>'
                                   , p_username =>               '<username>'
                                   , p_password =>               '<userpassword>'
                                   , p_filetype =>               'BINARY'
                                   , p_mainframe =>              'F'
                                   , p_mainframe_command =>      NULL);
--
   hum_ftp_utilities.get_remote_dir_long
                                      (errbuf =>                 l_errbuf
                                     , retcode =>                l_retcode
                                     , p_hostname =>             '<remoteserver>'
                                     , p_localpath =>            '<dba_directory_name>'
                                     , p_filename_filter =>      '*test*'
                                     , p_dir_filename =>         'remotedir_list.txt'
                                     , p_remotepath =>           '<absolutepath>'
                                     , p_username =>             '<username>'
                                     , p_password =>             '<userpassword>'
                                     , p_mainframe =>            'F');
--
   hum_ftp_utilities.put_remote_file(errbuf =>                   l_errbuf
                                   , retcode =>                  l_retcode
                                   , p_hostname =>               '<remoteserver>'
                                   , p_localpath =>              '<dba_directory_name>'
                                   , p_filename =>               'test.doc#test33.doc'
                                   , p_remotepath =>             '<absolutepath>'
                                   , p_username =>               '<username>'
                                   , p_password =>               '<userpassword>'
                                   , p_filetype =>               'BINARY'
                                   , p_mainframe =>              'F'
                                   , p_mainframe_command =>      NULL);
--
   hum_ftp_utilities.get_remote_dir_long
                                      (errbuf =>                 l_errbuf
                                     , retcode =>                l_retcode
                                     , p_hostname =>             '<remoteserver>'
                                     , p_localpath =>            '<dba_directory_name>'
                                     , p_filename_filter =>      '*test*'
                                     , p_dir_filename =>         'remotedir_list.txt'
                                     , p_remotepath =>           '<absolutepath>'
                                     , p_username =>             '<username>'
                                     , p_password =>             '<userpassword>'
                                     , p_mainframe =>            'F');
   DBMS_OUTPUT.put_line(' ');
   DBMS_OUTPUT.put_line('FINI');
END;
/