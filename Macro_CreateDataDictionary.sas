

/*_____________________________  PROGRAM INFO  _________________________________


Copyright [2022] Ming Zou, RepTik Analytics Solution, https://www.reptik.swiss 

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.



  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


I. ===== Purposes: ===== function /limitation /assumption /To-do 
  * Create SAS data dictionary for one or more or all datasets in a specific SAS dataset library. 
  * The generated Excel data dictionary contains rich summary information on 
    - All Datasets: e.g. number of variables, records, and unique keys. (default if >1 dataset)
    - All Variables: e.g. length, format, N(%) of missing /non-null /unique values. (default)
    - Optional: first 15 obs, and basic statistics (Min, P1, P25, Median, P75, P99, Max, Mean, Mode) of numeric variables.
    - Optional: frequencies - N(%) - for each unique values of all variables. 
    - Optional: remove the display of unique values for specific variables.
    - Optional: create a separate Excel data dictionary for each dataset.    
  
  * Example Use Cases: 
    - Explore a new set of data tables that you work for first time, get overview of tables, variables, unique values, statistics, etc. 
    - Generate table/variable/value overviews on a project specific datacut, substantially boost your analyses speeds!
    - Produce a catalog of information (so called "data dictionary") on a specific set of data tables, for other people to use, e.g. periodic deliveries.
  
  * Note 1: The program can be used in both Windows and Unix environment. Built with SAS 9.4.
  * Note 2: There're 5 macros in this file, where %SAS_Data_Dict() is the main macro and the others are supportive. 

  
II. ===== Inputs: ===== path /dataset /parameter /note
  * Required parameters for general output:
  + dsLib: target SAS dataset library, required.
  + dsList: dataset name(s) for creating the data dictionary, the name sequence is kept. Use %str() for null to get whole library. 
  + dirOUP: data dictionary file output path, required (remove ending "/" or "\").
  
  * Optional parameters for general output:
  + tagOUP: a string tag added at the end of the output file names, can be null.
  + keyList: list of linking keys across different datasets, count unique values for each key, can be null. 
  
  * Optional parameters for variable frequency output:
  + doValFreq: do frequency table for each unique value of all variables and all datasets, 1=Yes(default), 0=No.
  + oneDict: in the case of >1 datasets, output all data dict content to one single Excel file, 1=single(default), 0=multiple files.
  + oneShtFreq: output all variable frequency tables to only one Excel sheet, 1=Yes(default), 0=No (one sheet per var, only when oneDict=0).
  + varStrRmv: exclude frequency tables of varibles with specified strings list, delimete "|", can be null.
  
  * Note: very limited parameter checking statements were implemented. 
  * Example calls: 
    %SAS_Data_Dict(WORK, ds_Test, C:\output );
    %SAS_Data_Dict(WORK, %str(), C:\output, yyyy-mm-dd, key1 key2, oneDict=0, oneShtFreq=0 );

  
III. ===== Outputs: ===== path /dataset,file,value,print,log /note
  * In the case of >1 datasets,   
    1. Default output: one summary Excel report for all datasets on, 
    a) all dataset overview, like dataset name, number of variables, number of records, and number of unique keys. 
    b) all variable overview, like variable name, length, format, N(%) for missings /non-null /unique values. 
    c) all variable sample records (first 15 obs), and basic statistics for num var (Min, P1, P25, Median, P75, P99, Max, Mean, Mode).
    
    2. Optional output: individual detailed Excel reports for each dataset on,    
    a) all variable overview, same as 1-b above. 
    b) all variable sample records and basic statistics, same as 1-c above.
    c) all variable unique values: N(%) for each unique values of the same variable.
    
  * In the case of only 1 dataset,
    Default output: one detailed Excel report for the dataset on,    
    a) all variable overview, same as 1-b above. 
    b) all variable sample records and basic statistics, same as 1-c above.
    c) all variable unique values: N(%) for each unique values of the same variable.
    
  * Note 1: If oneShtFreq=1, all lengthy Char variables will be trimmed down to first 255 char for export/display.
  
  * Note 2: If oneShtFreq=1 and doValFreq=1, for var with <=400 unique values, all unique 
    values will be displayed. For var with >400 unique values, only 240 random values, 
    40 small values, 40 big values, 40 small counts, and 40 big counts will be displayed. An 'x' is 
    labeled in the 'Var_NAME' column value after the var position num, e.g. '1x_PatientID', '2x_EventDate'.
  
  * Note 3: If oneShtFreq=0 and doValFreq=1, for var with <=2,000 unique values, all unique values will 
    be displayed on its own worksheet. For var with >2,000 unique values, only 1200 random values, 
    200 small values, 200 big values, 200 small counts, and 200 big counts will be displayed. An 'x' is 
    labeled on the variable frequency sheet name after the var position num, e.g. '1x_PatientID', '2x_EventDate'.
 
 
IV. ===== History: ===== yyyy-mm-dd, v#.##, Author Name: Description
  * 2022-10-17, v1.01, Ming Zou: new build + test performance
  * 2022-11-25, v2.01, Ming Zou: add "oneDict" option to output all var freq info (one sheet per dataset) 
                          and all overview info to one single data dictionary Excel file. 
  * 2023-02-02, v2.10, Ming Zou: allow count of multiple linking keys across different datasets.


  
/*______________________________________________________________________________*/











/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    MACRO _1_  %SAS_Data_Dict
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


%macro SAS_Data_Dict( dsLib, dsList, dirOUP, tagOUP, keyList, doValFreq=1, oneDict=1, oneShtFreq=1, varStrRmv= );

	%local num listmem kyI kymem lst_cnt var_cnt obs_cnt key_cnt doStat dsShtNM time_st time_ed;
	%let time_st=%sysfunc( datetime(), E8601DT.); 
    %put ----------- Start Timestamp: &time_st. -----------; 
	 
    %let dirOUP = %sysfunc( translate( %quote(&dirOUP.),'/','\')); /* win path "\" -> unix path "/" */
	
	%let lst_cnt= %sysfunc(countw(&dsList.)); 
	%if &lst_cnt.=0 %then %do; /* do it for the whole library if no specific ds listed */   
        %if %upcase(&dsLib.)=WORK %then %put WARNING: ------------ ALL DATASETS in WORK library will be selected. ---------------;;
		proc sql noprint ;
			select distinct memName into :dsList separated by '  ' from sashelp.vmember
			where libname = "%upcase(&dsLib.)" and %upcase(%trim(memtype)) = "DATA"; /*and memname like "F_%" , tXL RAW tRW, capital letters!! */
		quit; 
		%let lst_cnt= %sysfunc(countw(&dsList.)); 
	%end; 
	
	%if &lst_cnt.=1 %then %do; 
        %let doValFreq=1; /* if only 1 ds, then default to create "Content_xxx" file, with %ds_var_freq table */
        %let oneDict=0; 
    %end; 
    %if &oneDict.>0 %then %let oneShtFreq=1;
  
	%put --------------- Data Dictionary for SAS Library (&dsLib.), with &lst_cnt. Datasets ------------------;
	%put ----------------- &dsList. --------------------;
	
	%if &lst_cnt.>1 %then %do; 
    /* if handling >1 dataset, create dataset and variable overview placeholder worksheets. */
		%ds_del( deldsn= &dsLib._tabALL  &dsLib._varALL);
		data &dsLib._tabALL; format TABLE $8. TABLE_NAME $80. VAR_COUNT best4. OBS_COUNT 8. ; run;
		data &dsLib._varALL; 
			format TABLE $8. POS best4. VAR_NAME $80. TYPE $5. LEN 8. FORMAT $15. LABEL $256. 
				Missing_count 8. Missing_percent 6.2 notNull_count 8. notNull_percent 6.2 notNull_unique 8. ; 
		run; 
		/* Create place holder worksheet */
		proc export data=&dsLib._tabALL outfile="&dirOUP./SAS_Data_Dictionary_&dsLib._&tagOUP..xlsx" 
			dbms=xlsx replace; sheet="TABLE_ALL"; run; 
		proc export data=&dsLib._varALL outfile="&dirOUP./SAS_Data_Dictionary_&dsLib._&tagOUP..xlsx" 
			dbms=xlsx replace; sheet="VARIABLE_ALL"; run; 
	%end;
	
	%let num=1;
	%let listmem=%upcase( %scan(&dsList.,&num.) ); /* delimiter: ,,%str( ) */
	%do %while(&listmem. ne) ; 
    /* For each ds, get summary table, 15obs + stat table, and var freq table.  ..ne %str( ) */
		%put ------------ Dictionary DS &num.:  &dsLib..&listmem. ---------------;
		%ds_del( deldsn= ds_view ds_ms_uq ds_15obs ds_stat s1 s2 s3 s4 s5 s6 s7 s8 s9 s10 s11 );
		%ds_sum_miss_uniq( &dsLib..&listmem., ds_ms_uq);
		
		data ds_ms_uq; set ds_ms_uq; 
            rename varnum=POS VARtype=TYPE Length=LEN; 
            if ^missing(varnum) then TABLE="#&num."; 
        run;
        %let doStat=.;
		proc sql noprint;
			select max(POS) into :var_cnt from ds_ms_uq;
			select 1 into :doStat from ds_ms_uq where type = 'Num' ; 
			select count(*) into :obs_cnt from &dsLib..&listmem.;
		quit; 
        
        data ds_view; format TABLE $8. TABLE_NAME $80. VAR_COUNT best4. OBS_COUNT 8. ;  
            TABLE = "#&num."; TABLE_NAME = "&listmem."; VAR_COUNT=&var_cnt.; OBS_COUNT=&obs_cnt.; 
        run;
        
		%if %length( &keyList.)>1 %then %do;
            /* Add unique counts of each key ID */
            %let kyI=1;
            %let kymem=%scan(&keyList.,&kyI.) ; /* delimiter: ,,%str( ) */
            %do %while(&kymem. ne) ; 
                %ds_del( deldsn= m_1keyN);
                %if %var_exist(&dsLib..&listmem.,&kymem.) %then %do;
                    proc sql noprint;
                        create table m_1keyN as 
                        select count(unique &kymem.) as &kymem._COUNT from &dsLib..&listmem.;
                    quit;
                    
                    data ds_view; merge ds_view m_1keyN; run;
                %end;
            
                %let kyI=%eval(&kyI. +1 ) ;
                %let kymem=%scan(&keyList., &kyI.) ;
            %end;
        %end;     
        
		data ds_15obs; length _STAT_ $10.; 
            set &dsLib..&listmem.(obs=15) end=last; _STAT_=cat("_",_N_,"_"); output;  
			if last then do; call missing(of _all_); output; end; /* add blank row at the end */
		run; 
		
		%if &doStat.>0 %then %do;
            proc means data=&dsLib..&listmem. noprint ;
                output out=s1(drop= _type_  _freq_) min=; 
                output out=s2(drop= _type_  _freq_) p1=;
                output out=s3(drop= _type_  _freq_) p25=;    
                output out=s4(drop= _type_  _freq_) median=;
                output out=s5(drop= _type_  _freq_) p75=;
                output out=s6(drop= _type_  _freq_) p99=;
                output out=s7(drop= _type_  _freq_) max=;  
                output out=s8(drop= _type_  _freq_) mean=;
                output out=s9(drop= _type_  _freq_) mode=;
                /* N, Nmiss: Char vars not calculated in this procedure */
            run;
          
            data ds_stat; length _STAT_ $10.; 
                set s1(in=a) s2(in=b) s3(in=c) s4(in=d) s5(in=e) s6(in=f) s7(in=g) s8(in=h) s9(in=i) ; 
                if a then do; _STAT_ = "MIN";    output; end;   
                if b then do; _STAT_ = "P1";     output; end; 
                if c then do; _STAT_ = "P25";    output; end; 
                if d then do; _STAT_ = "MEDIAN"; output; end; 
                if e then do; _STAT_ = "P75";    output; end; 
                if f then do; _STAT_ = "P99";    output; end; 
                if g then do; _STAT_ = "MAX";    output; call missing(of _all_); output; /* insert blank row */  end; 
                if h then do; _STAT_ = "MEAN";   output; end; 
                if i then do; _STAT_ = "MODE";   output; end; 
            run;
          
            data ds_15obs; set ds_15obs ds_stat ; run; 
		%end; 
      
        data s10; length VAR_TYPE N_NotNULL N_MISSING $12. ; 
          set ds_ms_uq(keep=VAR_name type Missing_count notNull_count); 
          drop Missing_count notNull_count type; 
          VAR_TYPE = type; N_notNull = put(notNull_count,8.); N_missing = put(Missing_count,8.); 
          if ^missing(type); 
        run;
        proc transpose data=s10 out=s11(rename=(_Name_=_STAT_ ) /*drop=type*/ ) ; id VAR_name; var VAR_TYPE N_notNull N_missing ; run; 
    
		%if &doValFreq.>0 and &oneDict.<1 %then %do; 
		/* for each dataset, create a separated xlsx "Content_xxx" file --> then list unique values for each VAR in separated worksheet */
			
			goptions reset=all; /* graphics options, always do this */
			ods excel file="&dirOUP./Contents_&dsLib._&listmem._&tagOUP..xlsx" 
                options(sheet_name="Overview" sheet_interval="table" embedded_titles='no' embedded_footnotes='no' ) 
                style=Minimal; /* Note: ods excel will overwrite existing file  */
            options sysprintfont=("Courier New" 10); 
      
			proc print data=ds_ms_uq(drop=TABLE) noobs style(header)={background=lightgrey font_weight=bold} ; run;
			
			ods excel options(sheet_name="15obs_Stat" sheet_interval="none" );
			proc print data=s11 noobs style(header)={background=lightgrey font_weight=bold} ; run; /* s11 dataset can be print only with ods output, so that on the same sheet of ds_15obs dataset */
			proc print data=ds_15obs noobs style(header)={background=lightgrey font_weight=bold} ; run; /* print with formats & labels of the values, 15obs + stat  */
			
            /* Note: proc print will truncate all Char var longer than 102$, for display. */
			ods results off;
			ods excel close; 
			ods results on; 
			
            options sysprintfont=("Courier New" 10); /* double confirm */
            %ds_var_freq( &dsLib..&listmem., &dirOUP./Contents_&dsLib._&listmem._&tagOUP..xlsx, oneShtFreq=&oneShtFreq., oneShtNM=All_var_freq, varStrRmv=&varStrRmv.);
		%end; 	
		
		
		/* Pool contents of each ds table, make "data dictionary" in one big table */		
		%if &lst_cnt.>1 %then %do; 
			data &dsLib._tabALL; set &dsLib._tabALL  ds_view; run;
			data &dsLib._varALL; set &dsLib._varALL  ds_ms_uq; 
				if var_name="&dsLib..&listmem." then var_name="#&num. -- &listmem.";
			run;
			%let dsShtNM=#&num._&listmem.;
            %if %length(&dsShtNM.)>30 %then %let dsShtNM = %qsubstr(&dsShtNM.,1,30);
			proc export data=ds_15obs outfile="&dirOUP./SAS_Data_Dictionary_&dsLib._&tagOUP..xlsx" 
				dbms=xlsx replace; sheet="&dsShtNM."; run; /* one sheet for each ds, 15obs + Stat. */
            %if &doValFreq.>0 and &oneShtFreq.>0 and &oneDict.>0 %then %do; /* if do oneShtFreq for >1 ds, then output freq to the same Excel file. */
                %ds_var_freq( &dsLib..&listmem., &dirOUP./SAS_Data_Dictionary_&dsLib._&tagOUP..xlsx, oneShtFreq=1, oneShtNM=#&num._freq, varStrRmv=&varStrRmv.);
            %end; 
		%end;
		
		%let num=%eval(&num. +1 ) ;
		%let listmem=%upcase( %scan(&dsList., &num.) );
	%end;
	
	%if &lst_cnt.>1 %then %do; 
		proc export data=&dsLib._tabALL outfile="&dirOUP./SAS_Data_Dictionary_&dsLib._&tagOUP..xlsx" 
			dbms=xlsx replace; sheet="TABLE_ALL"; run; /* fill placeholder */
		proc export data=&dsLib._varALL outfile="&dirOUP./SAS_Data_Dictionary_&dsLib._&tagOUP..xlsx" 
			dbms=xlsx replace; sheet="VARIABLE_ALL"; run; /* fill placeholder */
	%end;
	
	%let time_ed=%sysfunc( datetime(), E8601DT.); 
    %put ----------- End Timestamp: &time_ed. -----------; 
    data _null_; 
        st="&time_st."dt; ed="&time_ed."dt; d=intck('dtday',st,ed,'continuous'); t=ed-st; 
        put '**********************************************************************';
        put '.       --- Timestamp elapsed by:  ' d ' days  ' t tod. '  --- '; 
        put '**********************************************************************';
    run;
  
	
%mend SAS_Data_Dict;











/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    MACRO _2_  %ds_sum_miss_uniq
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


/*
I. ===== Purposes: ===== function /limitation /assumption /To-do
  * Create a content summary table of the input dataset, with detailed variable info, like 
    name, type, length, format, label, N(%) for missings, total and unique values, etc. 
  
II. ===== Inputs: ===== path /dataset /parameter /note
  * dsINP: input dataset name, required.
  * dsOUP: output dataset name, required.
  
III. ===== Outputs: ===== path /dataset,file,value,print,log /note
  * Output a SAS dataset containing the summary information on the input dataset.
  
IV. ===== History: ===== yyyy-mm-dd, v#.##, Author Name, Description
	* 2022-10-14, v1.01, Ming Zou: new build + test performance
  
*/
 

%macro ds_sum_miss_uniq(dsINP, dsOUP );
	%local nvar nobs dsID nm_pos ln_pos I nm_val ln_val rc ;
	%ds_del(deldsn= &dsOUP.	m_varlst m_stat_0 m_stat_1 m_stat_2 m_stat_3 m_stat_4 m_stat_5 m_stat_sum );
  
	options ibufsize=MAX ; /* for SQL table join: temporary index, max=32,767, default 0 (auto) */

	proc contents data=&dsINP. noprint
		out=m_varlst(keep=name type length format label varnum rename=(name=VAR_NAME) ); 
	run;
	proc sort data=m_varlst ; by varnum; run; 
	proc sql noprint; 
        select count(*) into:NVAR	from m_varlst; 
        select count(*) into:NOBS	from &dsINP.; 
    quit;

	data &dsOUP.; 
		format VARNUM best4. VAR_NAME $80. VARTYPE $5. LENGTH 8. FORMAT $15. LABEL $256. 
			Missing_count 8. Missing_percent 6.2 notNull_count 8. notNull_percent 6.2 notNull_unique 8. ; 
		VAR_NAME = ' '; output; VAR_NAME = "&dsINP."; output; 
	run;
	
	proc sql;
		create table m_stat_1 as 
		select 'Missing_count  ' as stat_chk,
			%let dsId=0; %let dsId = %Sysfunc( open(m_varlst)); 
			%let nm_pos = %Sysfunc( varnum( &dsId.,VAR_name)); 
			%let I=1;
			%do %while (%Sysfunc(fetch(&dsId.)) = 0);
				%let nm_val = %Sysfunc( getvarc(&dsId.,&nm_pos));
				%if &I ne &NVAR %then %do; 
				coalesce(sum(missing(&nm_val.)),0) as &nm_val. ,
				%end;
				%else %do; 
				coalesce(sum(missing(&nm_val.)),0) as &nm_val.  
				%end;
				%let I= %eval(&I + 1);
			%end;
			%let RC= %sysfunc( close(&dsId)); 
		from &dsINP. ;
	quit; 
      
	proc sql;
		create table m_stat_2 as 
		select 'Missing_percent' as stat_chk,
			%let dsId=0; %let dsId = %Sysfunc( open(m_varlst)); 
			%let nm_pos = %Sysfunc( varnum( &dsId.,VAR_name)); 
			%let I=1;
			%do %while (%Sysfunc(fetch(&dsId.)) = 0);
				%let nm_val = %Sysfunc( getvarc(&dsId.,&nm_pos));
				%if &I ne &NVAR %then %do; 
				coalesce(sum(missing(&nm_val.)),0)*100/&NOBS as &nm_val. ,
				%end;
				%else %do; 
				coalesce(sum(missing(&nm_val.)),0)*100/&NOBS as &nm_val. 
				%end;
				%let I= %eval(&I + 1);
			%end;
			%let RC= %sysfunc( close(&dsId)); 
		from &dsINP. ;
	quit; 
      
	proc sql;
		create table m_stat_3 as 
		select 'notNull_count  ' as stat_chk,
			%let dsId=0; %let dsId = %Sysfunc( open(m_varlst)); 
			%let nm_pos = %Sysfunc( varnum( &dsId.,VAR_name)); 
			%let I=1;
			%do %while (%Sysfunc(fetch(&dsId.)) = 0);
				%let nm_val = %Sysfunc( getvarc(&dsId.,&nm_pos));
				%if &I ne &NVAR %then %do; 
				coalesce(count(&nm_val.),0) as &nm_val. ,
				%end;
				%else %do; 
				coalesce(count(&nm_val.),0) as &nm_val. 
				%end;
				%let I= %eval(&I + 1);
			%end;
			%let RC= %sysfunc( close(&dsId)); 
		from &dsINP. ;
	quit; 
      
	proc sql;
		create table m_stat_4 as 
		select 'notNull_percent' as stat_chk,
			%let dsId=0; %let dsId = %Sysfunc( open(m_varlst)); 
			%let nm_pos = %Sysfunc( varnum( &dsId.,VAR_name)); 
			%let I=1;
			%do %while (%Sysfunc(fetch(&dsId.)) = 0);
				%let nm_val = %Sysfunc( getvarc(&dsId.,&nm_pos));
				%if &I ne &NVAR %then %do; 
				coalesce(count(&nm_val.),0)*100/&NOBS as &nm_val. ,
				%end;
				%else %do; 
				coalesce(count(&nm_val.),0)*100/&NOBS as &nm_val. 
				%end;
				%let I= %eval(&I + 1);
			%end;
			%let RC= %sysfunc( close(&dsId)); 
		from &dsINP. ;
	quit; 
      
	proc sql; 
    /* this step will consume lots of memory if the variable is a long free text with many obs */
		create table m_stat_5 as 
		select 'notNull_unique ' as stat_chk,
			%let dsId=0; %let dsId = %Sysfunc( open(m_varlst)); 
			%let nm_pos = %Sysfunc( varnum( &dsId.,VAR_NAME)); 
			%let ln_pos = %Sysfunc( varnum( &dsId.,LENGTH)); /* check length before move on, to avoid memory overflow for temp index */
			%let I=1;
			%do %while (%Sysfunc(fetch(&dsId.)) = 0);
				%let nm_val = %Sysfunc( getvarc(&dsId.,&nm_pos));
				%let ln_val = %Sysfunc( getvarn(&dsId.,&ln_pos));
				%if &ln_val lt 10000 %then %do; /* max length of a var is 32,767, take ~1/3 as threshold? */
          %if &I ne &NVAR %then %do; 
          coalesce(count(distinct &nm_val.),0) as &nm_val. ,
          %end;
          %else %do; 
          coalesce(count(distinct &nm_val.),0) as &nm_val. 
          %end;
        %end;
        %else %do; 
          %put WARNING: ------------ Variable &dsINP..&nm_val. is too long, skipped!! ------------; 
          %if &I ne &NVAR %then %do; 
          . as &nm_val. ,
          %end;
          %else %do; 
          . as &nm_val. 
          %end;
        %end;
				%let I= %eval(&I + 1);
			%end;
			%let RC= %sysfunc( close(&dsId)); 
		from &dsINP. ;
	quit; 
  
    data m_stat_0; set m_stat_1 m_stat_2 m_stat_3 m_stat_4 m_stat_5; run; 
  
  	
	proc transpose data=m_stat_0 out=m_stat_sum(rename=(_Name_=VAR_NAME)) ; id stat_chk; run;
	proc sort data=m_stat_sum; by var_name; run; 
	proc sort data=m_varlst; by var_name; run;
	data m_stat_sum; merge m_stat_sum m_varlst; by var_name; drop type; format vartype $4.;
		if type=1 then vartype='Num'; else if type=2 then vartype='Char'; run;
	proc sort data=m_stat_sum; by varnum; run; 
	data &dsOUP.; set &dsOUP. m_stat_sum; run; 
  
	options ibufsize=0 ; /* for SQL table join: temporary index, max=32,767(max length of a cell), default 0, */
	

%mend ds_sum_miss_uniq;








/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    MACRO _3_  %ds_var_freq
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


/*
I. ===== Purposes: ===== function /limitation /assumption /To-do
  * Calculate frequency (count & percent) of all unique values for each variable 
    in the input dataset.
  
II. ===== Inputs: ===== path /dataset /parameter /note
  * dsINP: input dataset name, required.
  * xlOUP: output Excel file path + name, required. 
  * oneShtFreq: output all variable frequency tables to only one Excel sheet, default: 0=No.
  * oneShtNM: name of the Excel sheet holding all frequency tables, required if oneShtFreq=1.
  * varStrRmv: Exclude frequency tables of varibles with specified strings list, delimete "|", can be null.
  
III. ===== Outputs: ===== path /dataset,file,value,print,log /note
  * Default: output frequency tables to an excel file, each variable with one worksheet.  
  * Option 1: append all frequency tables in one worksheet (oneShtFreq=1).
  * Option 2: can exclude variables containing specific strings (varStrRmv="ABC|CDE|date"). 
    
  * Note 1: If oneShtFreq=1, all lengthy Char variables will be trimmed down to first 255 char for export/display.
  
  * Note 2: If oneShtFreq=1 and doValFreq=1, for var with <=400 unique values, all unique 
    values will be displayed. For var with >400 unique values, only 240 random values, 
    40 small values, 40 big values, 40 small counts, and 40 big counts will be displayed. An 'x' is 
    labeled in the 'Var_NAME' column value after the var position num, e.g. '1x_PatientID', '2x_EventDate'.
  
  * Note 3: If oneShtFreq=0 and doValFreq=1, for var with <=2,000 unique values, all unique values will 
    be displayed on its own worksheet. For var with >2,000 unique values, only 1200 random values, 
    200 small values, 200 big values, 200 small counts, and 200 big counts will be displayed. An 'x' is 
    labeled on the variable frequency sheet name after the var position num, e.g. '1x_PatientID', '2x_EventDate'.
  
IV. ===== History: ===== yyyy-mm-dd, v#.##, Author Name, Description
	* 2022-10-13, v1.01, Ming Zou: new build + test performance
  
*/
 

%macro ds_var_freq(dsINP, xlOUP, oneShtFreq=0, oneShtNM=, varStrRmv= ); 
 	%local varseq num listmem vType vPOS vLen vFmt obsN uni_obs varnm t5k uLim uRan uTop;
	%ds_del( deldsn= vars var_sum );
  
	proc contents data = &dsINP. out = vars(keep = varnum name type length format )	noprint; run; 
	
	proc sql noprint;
        select count(*) into :obsN from &dsINP.; 
		select name into :varseq separated by ' ' from vars 
			%if %length(&varStrRmv.)>1 %then %do; where NOT (PRXMATCH("~&varStrRmv.~i",NAME))  %end; /* NOT (PRXMATCH('~ABC|CDE|FBV~i',NAME)) */
            order by varnum; 
	quit; 
	%put ------------- &dsINP. has &obsN. records, variable list: &varseq. ---------------;
	
	data var_sum; format Var_NAME $50. Val_SEQ 8. Date_VALUE date9. Num_VALUE 8. Char_VALUE_255 $255. COUNT 8. PERCENT 8. ; run;
	%let num=1;
	%let listmem=%scan(&varseq.,&num.) ; /* delimiter: &varseq.,&num.,%str( ) */
	%do %while(&listmem. ne and &obsN.>0) ; /* ne %str( ) */
		%ds_del( deldsn= var_fq var_nm );
		%put ------------- freq &num.: &listmem. ----------------;
		proc sql noprint; 
            select varnum into :vPos from vars where name="&listmem." ; 
            select length into :vLen from vars where name="&listmem." ; 
        quit; 
		title "%upcase(&dsINP.) ---- frequency of &vPos._&listmem.";
		%if &vLen.<10000 %then %do; /* potential memory issue for Var length*records, limit to 10k char */
        
            proc sql;
              create table var_fq as
              select &listmem., count(*) as COUNT, count(*)*100/&obsN. as PERCENT 
              from &dsINP. group by &listmem. ;
            quit; /* care: empty var for all records */

        %end; %else %do;
            %put WARNING: ------------ Variable &dsINP..&listmem. is too long, skipped!! ------------; 
            data var_fq; format &listmem. $50. COUNT 8. PERCENT 8. ; run;
        %end;
      
			proc sql noprint; select count(*) into :uni_obs from var_fq ; quit; /* already sorted by var value, assending */
        %if &oneShtFreq.=1 %then %do; 
            /* When stacking all freq in one sheet, reduce 2000 'boring' rows to only 400. 1000->200? */
            %let uLim=400; %let uRan=240; %let uTop=40; 
        %end; %else %do; 
            %let uLim=2000; %let uRan=1200; %let uTop=200; 
        %end; 
      
		%if &uni_obs.>&uLim. %then %do; /* no need to show massive unique values, >1000, >2000, >5000 */
            %ds_del( deldsn= vl_r1000 vl_s500 vl_b500 cn_s500 cn_b500 );
            %put ----------- This var has &uni_obs. unique values, only &uRan. random values, &uTop. small values, &uTop. big values, &uTop. small counts, and &uTop. big counts were exported. ------------; 
            proc sql outobs=&uRan.; /* 500, 1000, 2000 random */
                create table vl_r1000 as select * from var_fq order by ranuni(0);
            quit;
        
            data vl_s500; set var_fq (obs=&uTop.); run; /* keep 100, 200, 500 obs */
				
            proc sort data=var_fq; by descending &listmem.; run; 
            data vl_b500; set var_fq (obs=&uTop.); run; 
            
            proc sort data=var_fq; by count; run; 
            data cn_s500; set var_fq (obs=&uTop.); run; 
            
            proc sort data=var_fq; by descending count; run; 
            data cn_b500; set var_fq (obs=&uTop.); run; 
            
            data var_fq; set vl_r1000 vl_s500 vl_b500 cn_s500 cn_b500; run; 
            proc sort data=var_fq nodupkey ; by &listmem.; run; 
            %let t5k=x;
        %end;  %else %let t5k=;
        
        %if &oneShtFreq.=1 %then %do; 
            proc sql noprint; 
                select type into :vType  from vars where name="&listmem." ; 
                select upper(format) into :vFmt  from vars where name="&listmem." ; 
            quit; 
            data var_nm; length Var_NAME $50. ; Var_Name=' '; output; /* Var_Name="%cmpres(&vPos.)&t5k._&listmem." */ Var_Name=' '; output; run; 
            data var_fq; set var_fq; format Var_NAME $50. Val_SEQ 8.; Var_Name="%cmpres(&vPos.)&t5k._&listmem."; Val_SEQ=_N_; run;
            %if &vType.=1 %then %do;   /* type: 1 Num, 2 Char*/
                %if %index(&vFmt.,DATE)>0 or %index(&vFmt.,YY)>0 %then %do; /* date format */
                    data var_sum; set var_sum var_nm var_fq(rename=(&listmem.=Date_value ) ); run;
                %end; %else %do;
                    data var_sum; set var_sum var_nm var_fq(rename=(&listmem.=Num_value ) ); run;
                %end;
            %end; 
            %else %if &vType.=2 %then %do;
                data var_sum; set var_sum var_nm var_fq(rename=(&listmem.=Char_value_255 ) ); run;
            %end;
        %end; 
            
        %else %if %length(&xlOUP.)>1 %then %do; 
            %let varnm=%cmpres(&vPos.)&t5k._&listmem.; 
            %if %length(&varnm.)>30 %then %do;  
                %let varnm = %qsubstr(&varnm.,1,30); /* excel sheet name max 31 char */  
                %put ----------- sheet name > 30 char, trimmed = &varnm. ------------; 
            %end; 
            proc export data=var_fq outfile="&xlOUP." dbms=xlsx replace; sheet="&varnm."; run;
        %end; /* export only formatted values (e.g. date), or raw value without label (e.g. 1, label = "Female" ) */
		title;
		%let num=%eval(&num. + 1 ) ;
		%let listmem=%scan(&varseq., &num.) ;
	%end;
	
	%if &oneShtFreq.=1 and %length(&xlOUP.)>1 %then %do; 
		%if %length(&oneShtNM.)<1 %then %do; %let num=%eval(&num. - 1 ); %let oneShtNM=freq_&dsINP.; %end; 
		%if %length(&oneShtNM.)>30 %then %let oneShtNM = %qsubstr(&oneShtNM.,1,30);
		proc export data=var_sum outfile="&xlOUP." dbms=xlsx replace; sheet="&oneShtNM."; run;
	%end; 

%mend ds_var_freq;









/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    MACRO _4_  %var_exist
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

/*
I. ===== Purposes: ===== function /limitation /assumption /To-do
  * Check for the existence of a specified variable.
    Use SYSFUNC to execute OPEN, VARNUM, and CLOSE functions.
  
II. ===== Inputs: ===== path /dataset /parameter /note
  * ds: Dataset name, required.
  * var: Variable name, required.
  
    %if %var_exist(&data,NAME)
      %then %put input data set contains variable NAME;
  
III. ===== Outputs: ===== path /dataset,file,value,print,log /note
  * The macro calls resolves to 0 when either the data set does not exist
    or the variable is not in the specified data set.
  
IV. ===== History: ===== yyyy-mm-dd, v#.##, Author Name, Description
  * Adapted from internet, unknown author... 
  
*/
 
%macro var_exist(ds, var);
	 
	%local dsid rc ;
	%let dsid = %sysfunc(open(&ds));
	 
	%if (&dsid) %then %do;
        %if %sysfunc(varnum(&dsid,&var)) %then 1;
        %else 0 ;
        %let rc = %sysfunc(close(&dsid));
	%end;
	%else 0;
	 
%mend var_exist;









/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    MACRO _5_  %ds_del
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


/*
I. ===== Purposes: ===== function /limitation /assumption /To-do
  * Control what datasets of a specific SAS library to be deleted or kept.
  
II. ===== Inputs: ===== path /dataset /parameter /note
  * libnm: target SAS dataset library name.
  * kill: Option to delete all temporary datasets. 1 - delete all temp
          datasets, 0 - not delete all dataset, Default is 0.
  * savedsn: Name of dataset or list of datasets to be saved, separated
          by space(blank) only.
  * deldsn:	Name of dataset or list of datasets to be deleted.
  * delim: Delimeter, default is blank, could be any special character
          except ','.
  --------------------------------------------------
    Typical calls: 				Explanation:

    %ds_del(kill=1); 			1) Delete all temporary datasets.
    %ds_del(savedsn=pop); 		2) Save only pop dataset. Delete all
                  other temp datassets.
    %ds_del(savedsn=pop baseline dummy); 3) Save datasets pop, baseline, and
                  dummy. Delete all other temp
                  datasets.
    %ds_del(deldsn=test); 		4) Delete only test dataset. Save
                  all other temp datasets.
    %ds_del(deldsn=test check baseline
     change); 					5) Delete datasets test, check,
                  baseline, and change. Save
                  other datasets.
    %ds_del(deldsn=test/check/baseline/change,
     delim=/); 					6) Delete datasets test, check,
                  baseline, and change and list
                  them using delimeter '/'.
  --------------------------------------------------
  
III. ===== Outputs: ===== path /dataset,file,value,print,log /note
  Note: This macro should be called at the beginning of each program.
  '%*' is a comment
  
IV. ===== History: ===== yyyy-mm-dd, v#.##, Author Name, Description
  * Adapted from internet, unknown author... 
  
*/
 
 
%macro ds_del(libnm =work,
		  kill =0,
		  savedsn =,
		  deldsn =,
		  delim =%str( )
		  );
	%local libnm kill savedsn deldsn delim dsid rc ;
	%PUT MYNOTE: Now executing macro %upcase(&sysmacroname) for library "&libnm.";

	%if &kill=1 and %str(&savedsn)=%str() and %str(&deldsn)=%str() and
	%str(&delim)=%str() %then %do;
        proc datasets library=&libnm. mt=data kill nolist;
        run;quit;
	%end;

	%else %if &kill=0 and %str(&savedsn) ne %str() and %str(&deldsn)=%str() %then
	%do;
        proc datasets library=&libnm. mt=data nolist;
            save &savedsn;
        run;quit;
	%end;

	%else %if &kill=0 and %str(&savedsn)=%str() and %str(&deldsn) ne %str() %then
	%do;
		%local dsn dsnexist i;
		%let i=1;
		%let dsn=%qscan(&deldsn, &i, &delim);

		%do %while(&dsn ne %str());
            %let i=%eval(&i + 1);
            %let dsnexist=%sysfunc(exist(&libnm..&dsn));
      
            %if &dsnexist=1 %then %do;
            %* release dataset &dsnexist;
            %let rc=%sysfunc(close(&dsnexist));
            proc datasets library=&libnm. mt=data nolist; 
                delete &dsn;
            run;quit;
            %end;
      
            %else %do;
                %put MYNOTE: Dataset %upcase(&dsn) does not exist.;
            %end;
      
            %let dsn=%qscan(&deldsn, &i, &delim);
		%end;
	%end;

	%else %do;
		%if &kill=1 and %str(&savedsn) ne %str() %then %do;
          %put MYNOTE: All temporary datasets will be deleted. If you want to save
          the listed dataset(s), please ignore parameter KILL.;
          %goto endmac;
		%end;
		
		%if &kill=1 and %str(&deldsn) ne %str() %then %do;
          %put MYNOTE: All temporary datasets will be deleted. If you want to delete
          the listed dataset(s), please ignore parameter KILL.;
          %goto endmac;
        %end;
		
		%if %str(&savedsn) ne %str() and %str(&deldsn) ne %str() %then %do;
          %put MYNOTE: Only listed dataset(s) will be saved. Please specify only
          one parameter, either savedsn= or deldsn=.;
          %goto endmac;
		%end;
	%end;

	%endmac:
%mend ds_del; 









/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    MACRO _###_  XXX-KeyWords ------- Template ---------
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


/*************************

I. ===== Purposes: ===== function /limitation /assumption /To-do
  * XXX
    - XXX
      + XXX
  
II. ===== Inputs: ===== path /dataset /parameter /note
  * XXX
  
III. ===== Outputs: ===== path /dataset,file,value,print,log /note
  * XXX
  
IV. ===== History: ===== yyyy-mm-dd, v#.##, author name, change description
	* 202#-10-20, v0.01, Author XXX: new build + test performance
  
*************************/









/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    END OF PROGRAM - Create SAS Data Dictionary for one or more datasets.
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/








