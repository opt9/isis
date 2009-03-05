require ("profile");

private variable Version = "0.2.1-1";
private variable Profile_Fp;

private define _slprof_version ()
{
   () = fprintf (stderr, "slprof version %s; S-Lang version: %s\n",
		 Version, _slang_version_string);
}

private define _slprof_usage ()
{
   variable fp = stderr;
   () = fprintf (fp, "Usage: isis --prof [options] script args...\n");
   () = fprintf (fp, "Options:\n");
   variable opts =
     [
      " -c|--calibrate <N>         Calibrate using N repetitions [default:1000, 0=off]\n",
      " -f|--func <function>       Name of Function to call [default: slsh_main]\n",
      " -l|--lines                 Profile lines, not just functions\n",
      " -o|--output <file>         Name of output file [default: <script>.slprof]\n",
      " -v|--version               Print version information\n",
      " -h|--help                  Print this message\n"
     ];
   variable opt;
   foreach opt (opts)
     () = fputs (opt, fp);
   exit (1);
}

private define _slprof_write_profile ()
{
   profile_report (Profile_Fp);
   () = fclose (Profile_Fp);
}

private define _slprof_calibrate (n)
{
   if (n == 0)
     return;
   () = fprintf (stdout, "Calibrating profiler..."); ()=fflush (stdout);
   profile_calibrate (n);
   () = fprintf (stdout, "Done\n");
}

private define _slprof_main ()
{
   variable output = NULL;
   variable func = "isis_main";
   variable line_by_line = 0;
   variable cal_n = 1000;

   variable i = 0;
   while (i < __argc)
     {
	variable arg = __argv[i]; i++;
	if ((arg == "-c") or (arg == "--calibrate"))
	  {
	     if (i == __argc)
	       _slprof_usage ();
	     if (1 != sscanf (__argv[i], "%d", &cal_n))
	       _slprof_usage ();
	     if (cal_n < 0)
	       cal_n = 0;
	     i++;
	     continue;
	  }

	if ((arg == "-f") or (arg == "--func"))
	  {
	     if (i == __argc)
	       _slprof_usage ();
	     func = strtrim (__argv[i]);
	     if (func == "")
	       _slprof_usage ();
	     i++;
	     continue;
	  }
	if ((arg == "-l") or (arg == "--lines"))
	  {
	     line_by_line = 1;
	     continue;
	  }
	if ((arg == "-o") or (arg == "--output"))
	  {
	     if (i == __argc)
	       _slprof_usage ();
	     output = __argv[i];
	     i++;
	     continue;
	  }
	if ((arg == "-v") or (arg == "--version"))
	  {
	     _slprof_version ();
	     exit (0);
	  }

	if ((arg == "-h") or (arg == "--help"))
	  _slprof_usage ();

	if (arg[0] == '-')
	  _slprof_usage ();

	i--;
	break;
     }

   if (i == __argc)
     _slprof_usage ();

   variable main = strtok (func, " \t(;")[0];
   variable main_args = strtrim (substrbytes (func, 1+strlen(main), -1));

   variable depth = _stkdepth();
   try
     {
	if (strlen (main)) eval (main_args);
     }
   catch AnyError:
     {
	() = fprintf (stderr, "Error parsing args of %s\n", func);
	exit (1);
     }
   main_args = __pop_args (_stkdepth ()-depth);

   variable script = __argv[i];

   if (not path_is_absolute (script))
     script = path_concat (getcwd (), script);

   variable st = stat_file (script);
   if (st == NULL)
     {
	() = fprintf (stderr, "Unable to stat %s -- did you specify its path?\n", script);
	exit (1);
     }

   if (not stat_is ("reg", st.st_mode))
     () = fprintf (stderr, "*** Warning %s is not a regular file\n", script);

   if (output == NULL)
     output = strcat (path_basename_sans_extname (script), ".slprof");

   variable fp = fopen (output, "w");
   if (fp == NULL)
     {
	() = fprintf (stderr, "Unable to profiler output file %s\n");
	exit (1);
     }
   () = fprintf (fp, "# slprof profile report for:\n");
   () = fprintf (fp, "#  %S\n\n", strjoin (__argv, " "));
   Profile_Fp = fp;

   variable has_at_exit = 0;
#ifexists atexit
   atexit (&_slprof_write_profile);
   has_at_exit = 1;
#endif

   __set_argc_argv (__argv[[i:]]);

   % Actual profiling starts here

   _slprof_calibrate (cal_n);
   profile_begin (line_by_line);
   () = evalfile (script);

   variable ref = __get_reference (main);
   if (ref != NULL)
     (@ref) (__push_args (main_args));
   else if (main != "isis_main")
     () = fprintf (stderr, "*** Warning: %s is not defined\n", main);

   profile_end ();

   if (has_at_exit == 0)
     _slprof_write_profile ();
}

_slprof_main ();
