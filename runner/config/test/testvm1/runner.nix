{ pkgs }:
let inherit pkgs;
in {
  "command" = "Start";
  "database.host" = "${pkgs.my-db-config.db.host}";
  "database.port" = "${pkgs.my-db-config.db.port}";
  "database.user" = "${pkgs.my-db-config.db.user}";
  "database.password" = "${pkgs.my-db-config.db.password}";
  "database.database" = "${pkgs.my-db-config.db.database}";
  "pool.stripe" = 1;
  "pool.idletime" = 1800;
  "pool.size" = 10;
  "oddjobsstartargs.webuiauth" = "Nothing";
  "oddjobsstartargs.webuiport" = 5555;
  "oddjobsstartargs.daemonize" = "True";
  "oddjobsstartargs.pidfile" = "/var/${pkgs.userName}/run/my-job-runner.pid";
  "oddjobsstopargs.timeout" = 60;
  "oddjobsstopargs.pidfile" = "/var/${pkgs.userName}/run/my-job-runner.pid";
  "oddjobsconfig.tablename" = "data.jobs";
  "oddjobsconfig.jobrunner" = "";
  "oddjobsconfig.defaultmaxattempts" = 5;
  "oddjobsconfig.concurrencycontrol" = 5;
  "oddjobsconfig.dbpool" = "";
  "oddjobsconfig.pollinginterval" = 5;
  "oddjobsconfig.onjobsuccess" = "";
  "oddjobsconfig.onjobfailed" = "";
  "oddjobsconfig.onjobstart" = "";
  "oddjobsconfig.onjobtimeout" = "";
  "oddjobsconfig.pidfile" = "/var/${pkgs.userName}/run/my-job-runner.pid";
  "oddjobsconfig.logger" = "";
  "oddjobsconfig.jobtype" = "";
  "oddjobsconfig.jobtypesql" = "";
  "oddjobsconfig.defaultjobtimeout" = 1800;
  "oddjobsconfig.jobtohtml" = "";
  "oddjobsconfig.alljobtypes" = "";
  "cmdpath.xvfbpath" = "${pkgs.xvfb-run}/bin/xvfb-run";
  "cmdpath.wgetpath" = "${pkgs.wget}/bin/wget";
  "cmdpath.curlpath" = "${pkgs.curl}/bin/curl";
  "cmdpath.javapath" = "${pkgs.jdk11}/bin/java";
  "cmdpath.parsedumpshpath" =
    "${pkgs.my-eclipse-mat-with-dtfj}/mat/ParseHeapDump.sh";
  "cmdpath.jcapath" = pkgs.my-jca.src;
  "cmdpath.gcmvpath" = "gcmv";
  "outputpath.fetcheddumphome" = "/var/${pkgs.userName}/data/raw_dump_files";
  "outputpath.jcapreprocessorhome" =
    "/var/${pkgs.userName}/data/preprocessed_report_jca";
  "outputpath.matpreprocessorhome" =
    "/var/${pkgs.userName}/data/preprocessed_report_mat";
  "outputpath.gcmvpreprocessorhome" =
    "/var/${pkgs.userName}/data/preprocessed_report_gcmv";
  "outputpath.jcareporthome" = "/var/${pkgs.userName}/data/parsed_report_jca";
  "outputpath.matreporthome" = "/var/${pkgs.userName}/data/parsed_report_mat";
  "outputpath.gcmvreporthome" = "/var/${pkgs.userName}/data/parsed_report_gcmv";
  "outputpath.jcapostprocessorhome" =
    "/var/${pkgs.userName}/data/postprocessed_report_jca";
  "outputpath.matpostprocessorhome" =
    "/var/${pkgs.userName}/data/postprocessed_report_mat";
  "outputpath.gcmvpostprocessorhome" =
    "/var/${pkgs.userName}/data/postprocessed_report_gcmv";
  "jcacmdlineoptions.xmx" = 2048;
  "matcmdlineoptions.xmx" = 2048;
  "gcmvcmdlineoptions.xmx" = 2048;
  "gcmvcmdlineoptions.jvm" = pkgs.jdk11;
  "gcmvcmdlineoptions.preference" = "/usr/local/gcmv/default_preference.emf";
  "curlcmdlineoptions.loginuser" = "test1@test1.com";
  "curlcmdlineoptions.loginpin" = "pass1234";
  "curlcmdlineoptions.loginurl" = "http://127.0.0.1/rest/rpc/login";
  "curlcmdlineoptions.uploadurl" = "http://127.0.0.1/uploadreport";
}
