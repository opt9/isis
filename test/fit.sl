% -*- mode: SLang; mode: fold -*-
() = evalfile ("inc.sl");
msg ("testing fit.... ");

%{{{ Test slang function definitions.

define testfun1_fit(l,h,p){return urand(length(l));}
add_slang_function ("testfun1", ["a", "b", "norm"]);
fit_fun ("testfun1(1)");
private variable _t = get_params();
!if (andelse
    {_t[0].is_a_norm == 0}
    {_t[1].is_a_norm == 0}
    {_t[2].is_a_norm == 1})
{
   failed ("[1]norm indexes don't match");
}
define testfun2_fit(l,h,p){return urand(length(l));}
add_slang_function ("testfun2", ["norm", "a", "b"], [0,2]);
fit_fun ("testfun2(1)");
private variable _t = get_params();
!if (andelse
    {_t[0].is_a_norm == 1}
    {_t[1].is_a_norm == 0}
    {_t[2].is_a_norm == 1})
{
   failed ("[2]norm indexes don't match");
}

%}}}

define check_num_pars (num_expected, id_string)
{
   if (num_expected != get_num_pars ())
     failed ("wrong number of params [%s]! => %d (expected %d)",
	     id_string,
	     get_num_pars(), num_expected);
}

define match_pars (pars) %{{{
{
   variable i, num_pars = get_num_pars ();
   for (i = 0; i < num_pars; i++)
     {
	if (get_par(i+1) != pars[i].value)
	  return -1;
     }

   return 0;
}

%}}}

% Test basic operations
define test_basic_ops (freeze_par, tie_par, test_name) %{{{
{
   variable old_pars, pars, num_pars;

   % copy/restore
   old_pars = get_params();
   if (old_pars == NULL) failed ("%s: %s", test_name, "get_params");
   randomize;
   pars = get_params();
   num_pars = get_num_pars();
   if (num_pars != length(pars)) failed ("%s: %s", test_name, "get_num_pars");
   if (0 != match_pars (pars)) failed ("%s: %s", test_name, "get_par");
   set_params (old_pars);
   if (0 != match_pars (old_pars)) failed ("%s: %s", test_name, "set_params");

   % freeze, thaw, tie, untie
   freeze(freeze_par);
   if (get_par_info(freeze_par).freeze != 1) failed ("%s: %s", test_name, "freeze");
   thaw(freeze_par);
   if (get_par_info(1).freeze != 0) failed ("%s: %s", test_name, "thaw");
   tie(tie_par,freeze_par);
   if (_get_index(get_par_info(freeze_par).tie) != _get_index(tie_par)) failed ("%s: %s", test_name, "tie");
   untie(freeze_par);
   if (_get_index(get_par_info(freeze_par).tie) != NULL) failed ("%s: %s", test_name, "untie");

   variable save_tie_par, fp, fun;

   % Define params as functions of other params
   %  tie_par <= f(freeze_par);
   save_tie_par = get_par (tie_par);
   fp = get_par (freeze_par);
   fun = sprintf ("_par(%d)*1.1", _get_index(freeze_par));
   variable x = get_par_info(tie_par);
   % widen the upper limit before this will work
   set_par (tie_par, x.value, x.freeze, x.min, 20);
   set_par (tie_par, fun);
   if (0 != strcmp (get_par_info (tie_par).fun, fun)
       or get_par(tie_par) != fp*1.1)
     failed ("%s: %s", test_name, "set_par_fun[1]");

   set_par_fun (tie_par, NULL);
   if (get_par_info (tie_par).fun != NULL)
     failed ("%s: %s", test_name, "set_par_fun[2]");
   set_par (tie_par, save_tie_par);

   % save and restore
   variable par_file = ".isis." + string(getpid());
   () = remove (par_file);
   save_par (par_file);
   old_pars = get_params();
   fit_fun ("delta(1)");
   load_par (par_file);
   if (0 != match_pars (old_pars)) failed ("%s: %s", test_name, "save_par/load_par");
   () = remove (par_file);
}

%}}}

private variable Arf_Id = NULL;
define make_unit_arf (lo, hi)
{
   variable unit_arf = ones(length(lo));
   Arf_Id = define_arf (lo, hi, unit_arf, 0.01*unit_arf);
}

define add_fake_dataset () %{{{
{
   variable x = grand(100000);
   x += 2*abs(min(x));

   variable n, lo, hi;
   n = 1024;
   (lo, hi) = linear_grid (min(x), max(x), n);

   variable nx = histogram (x, lo, hi);
   nx += 10;
   variable id = define_counts (lo, hi, nx, sqrt(nx));
   if (id < 0) failed ("init_fake_data");

   % Assigning an arf to avoid an error from the
   % pileup kernel about needing a factored response.
   if (Arf_Id == NULL) make_unit_arf (lo, hi);
   assign_arf (Arf_Id, id);

   set_frame_time (id, 3.2);
   variable info = get_data_info (id);
   info.order = 1;
   set_data_info (id, info);

   return id;
}

%}}}

define try_user_statistic () %{{{
{
   fit_fun ("Lorentz(1)");
   set_par (1,15000, 0, 1500, 1.e9);
   set_par (2,12);
   set_par (3,0.05);

   variable lo, hi, val;
   (lo,hi) = linear_grid (11.6,12.4,32);
   val = eval_fun (lo,hi);
   () = define_counts (lo,hi,val, prand(val));

   set_fit_statistic ("chisqr");
   variable chi_info;
   if (-1 == eval_counts(&chi_info))
     failed ("max_like [chisqr]");

   () = evalfile ("max_like.sl");
   if (NULL == get_fit_statistic ())
     failed ("max_like [name]");

   variable max_info;
   if (-1 == eval_counts(&max_info))
     failed ("max_like [1]");

   if (max_info.statistic == chi_info.statistic)
     failed ("max_like [2]");
}

%}}}

% a simple fit function
fit_fun ("gauss(1)");
check_num_pars (3, "simple");
test_basic_ops (2, 3, "simple");
test_basic_ops ("gauss(1).center", "gauss(1).sigma", "simple");

% odd corner cases
fit_fun ("poly(1) + poly(1)");
check_num_pars (3, "corner");

% kernel parameters
variable id = add_fake_dataset ();
set_kernel (id, "pileup");
check_num_pars (7, "pileup");
test_basic_ops (1, 6, "pileup");

% A second dataset and kernel
id = add_fake_dataset ();
set_kernel (id, "pileup");
check_num_pars (11, "pileup");
test_basic_ops (2, 3, "two kernels");

% Add an instrumental background
back_fun (1, "Powerlaw(1)");
check_num_pars (13, "back[1]");
test_basic_ops (3, 9, "back");
back_fun (1, NULL);
check_num_pars (11, "back[2]");

% Now let each dataset get its own function....
define schizo () %{{{
{
   switch (Isis_Active_Dataset)
     {
      case 1:
	return poly(1) + blackbody(1);
     }
     {
      case 2:
	return Powerlaw(2);
     }
     {
	% default:
	message ("*** [schizo] too many datasets");
	exit(1);
     }
}

%}}}
fit_fun ("schizo");
back_fun (2, "poly(2)");
% poly(1) + blackbody(1) + powerlaw(2) => 7
%                      pileup + pileup => 5
%                              poly(2) => 3
%                             --------------
%                                        15 params
check_num_pars (18, "function per dataset");
test_basic_ops (14, 3, "function per dataset");
back_fun (2, NULL);
check_num_pars (15, "function per dataset");

% first dataset => standard kernel
% and lose pileup parameters
set_kernel (1, "std");
check_num_pars (11, "revert to std");
test_basic_ops (1, 4, "revert to std");

% Now delete a dataset
%  poly(1) + blackbody(1) => lose 5
delete_data (1);
check_num_pars (6, "delete dataset");
test_basic_ops (1, 2, "delete dataset");

% user-defined functions
() = evalfile("bpl.sl");
fit_fun ("bpl(1)");
bpl_set_default (0);
check_num_pars (8, "S-Lang fit-function");
test_basic_ops (3, 4, "S-Lang fit-function");

% user-defined statistic
delete_data (all_data);
check_num_pars (4, "UDF");
try_user_statistic ();

% parameter counting
delete_data (all_data);
set_fit_statistic ("chisqr");
define cnst_fit(l,h,p){ return p[0] * ones(length(l));}
add_slang_function ("cnst", "a");
fit_fun("cnst(Isis_Active_Dataset)");
()=define_counts(1,2,3,4);
()=define_counts(2,3,4,5);
variable info;
() = eval_counts (&info);
if ((info.num_variable_params != 2)
    || (info.num_bins != 2))
{
   throw ApplicationError, "*** eval_counts parameter counting problem";
}

% set_par should respect tied parameters
tie(2,1);
set_par (1, 3.5);
private variable p = get_par_info (1);
if (p.tie != "cnst(2).a")
{
   throw ApplicationError, "*** set_par broke parameter tie";
}

% data/model sync
delete_data (all_data);
()=define_counts(1,2,3,4);
fit_fun("cnst(Isis_Active_Dataset)");
()=define_counts(2,3,4,5);
()=define_counts(2,3,4,5);
set_par ("cnst(3).a", 4);
if (4 != get_par ("cnst(3).a"))
{
   throw ApplicationError, "data/model sync error";
}

% set_params/get_params

private variable Test_Name;
define check_equality (p, p0) %{{{
{
   if (p.freeze != p0.freeze
       or p.tie != p0.tie
       or p.min != p0.min
       or p.max != p0.max
       or p.fun != p0.fun
       or p.value != p0.value)
     {
        print(p0);
        print(p);
	failed ("restoring initial parameter config: %s", Test_Name);
     }
}

%}}}

define compare_pars (pars, pars0) %{{{
{
   variable i, ids = [1:get_num_pars()];
   variable p, p0;

   foreach (ids)
     {
	i = ();
	p = pars[i-1];
	p0 = pars0[i-1];

	check_equality (p, p0);
     }
}

%}}}

delete_data (all_data);
() = define_counts (1,2,3,4);
fit_fun ("blackbody(1) + blackbody(2)");
set_par ("blackbody(1).norm", 1.5, 0, 0.5, 4.5);

define mod1(){ tie("blackbody(1).norm", "blackbody(2).norm");}
define mod2(){ set_par_fun ("blackbody(2).kT", "2 * blackbody(1).kT");}
define undo_mod1(){ untie("blackbody(2).norm");}
define undo_mod2(){ set_par_fun ("blackbody(2).kT", NULL);}

Test_Name = "simple case -- restore state with no ties or derived params";
variable p0 = get_params();
mod1(); mod2();
set_params (p0);
compare_pars (get_params(),p0);

Test_Name = "restore state with param ties";
mod1();
variable p1 = get_params();
undo_mod1(); undo_mod2();
set_params (p1);
compare_pars (get_params(),p1);

Test_Name = "restore state with derived params";
set_params (p0);
mod2();
variable p2 = get_params();
undo_mod1(); undo_mod2();
set_params (p2);
compare_pars (get_params(),p2);

% load_par should be able to untie parameters %{{{

delete_data(all_data);
fit_fun ("gauss");

variable pfile = "x.p";
if (0 == access(pfile, F_OK))
  throw ApplicationError, "*** $pfile exists!"$;

% save state with no ties
save_par (pfile);

% tie 2 params together
tie (1,2);

% check that the tie is established
if (NULL == get_par_info(2).tie)
  throw ApplicationError, "*** parameter should be tied!!";

% load the un-tied state
load_par (pfile);

% check that the tie is now broken
if (NULL != get_par_info(2).tie)
  throw ApplicationError, "*** parameter should not be tied!!";

% remove the temporary parameter file
if (0 != remove(pfile))
   throw ApplicationError, "*** can't remove $pfile!"$;

%}}}

msg ("ok\n");
