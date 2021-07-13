# plsql-ftp-interface
FTP Interface PLSQL based - using UTL_TCP



This latest edition of the FTP_INTERFACE has been modified to support LS/DIR commands.
The LS command provides directory results of remote server in filename only format. The
DIR command provides directory results of remote server in full detail (long-version).

Additionally, you have the option of displaying filematches. Normally a ls/dir command
does not permit the option of declaring filename filters. However, this new version will
effectively do just that. In reality, it is still pulling back the entire directory tree
for the remote path identified, however the result file created will only have your matches.
It is important to be cautious of leaving it as a wildcard (*) alone which returns everything
in the remote path. The reason being is if there is a lot, then your resulting output could
be quite a large file.

You will also find full CLOB/BLOB support for api calls. No filesystem required. 

Along with this new version, I am also providing a handy package that you can build concurrent
manager jobs with to utilize in an Oracle Applications environment. This makes using the new
FTP PLSQL solution very easy to use for everyone.

You will need to compile the PS_PARSE package into your environment as well. We leverage it to
build arrays from text string that are piped together.

I have provided a sample script that demonstrates how the ls/dir command is used. I am leveraging
the FTP_UTILITIES calls. I have ran these calls in my concurrent manager jobs and they work
very well.

As always, please feel free to comment and/or improve this code. Most importantly, freely distribute
it. Please maintain the credits, as a lot of work has gone into the creation of this code by
many hands.




FILES INCLUDED

PS_PARSE		:: Array and Parsing package
FTP_INTERFACE	:: Core FTP package
FTP_UTILITIES :: Wrapper routines that can be used in Oracle Applications or optionally PLSQL code

Note :

We use a print_output procedure in our packages as provided here. However, in our environment here
I created a module within a utility package that allows me to alternatively push output to DBMS, LOG, or OUTPUT.
The latter two are specific to Oracle Applications environment. Those that are using Oracle Applications
will already be familiar with the intended functionality represented here.

Default mode is to the Oracle Applications LOG, but we can also specify OUTPUT or DBMS. We build most of our
code to default to LOG. However that causes issues when trying to debug or run the code stand alone outside
of the Oracle Applications concurrent scheduler. So by declaring for the session the spec variable p_print_output_mode
and making it a value of DBMS, we essentially override the coded operation. It won't go to LOG now for the duration
of your session or until you set the spec variable back to NULL.

It also permits the display of up to 1000 characters of DBMS without experiencing a buffer overflow which is occurs
at 255 per line of output. LOG and OUTPUT do not have this limitation because the Oracle Applications evironment
writes entries directly to a file.

I have included an example of the package you might use, and references within the FTP_INTERFACE.PRINT_OUTPUT routine.


As a reminder to all those who have contributed to the success of this code solution and future
contributors :

      * --
      *  FTP_INTERFACE package created by Russ Johnson. rjohnson@braunconsult.com
      *   http://www.braunconsult.com
      *
      *  Much of the PL/SQL code in this package was based on Java code written by
      *  Bruce Blackshaw of Enterprise Distributed Technologies Ltd.  None of that code
      *  was copied, but the objects and methods greatly helped my understanding of the
      *  FTP Client process.
      *
      *  http://www.enterprisedt.com
      * --
      *
      * --
      *  Technical article wrriten by Dmitry Bouzolin. dbouzolin@yahoo.com
      *     http://www.quest-pipelines.com/newsletter-v3/0302_C.htm
      * --
      *
      * --
      *  FTP package created by Timothy Hall
      *  http://www.oracle-base.com/articles/9i/FTPFromPLSQL9i.php
      * --
      *
      * --
      *  FTP command reference
      *   http://cr.yp.to/ftp.html
      * --
      *
      * --
      *  Ask Tom - Oracle Forum
      *   http://asktom.oracle.com

      * --
      * Paul James donated support for LIST and NLIST commands
      * http://daemoncoder.blogspot.com/
      * http://technology.amis.nl/blog/1247/implementing-an-ftp-server-in-plsql
      *
      * --
      *
      * --
      *  The W3C's RFC 959 that describes the FTP process.
      *  http://www.w3c.org
      * --
      *  Paul James. Downloaded code from my website and added LS/NLST features. I later added some
      *  additional enhancements so that a filter match could be made instead of grabbing list of all
      *  files.
      * --
      *

