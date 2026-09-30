function fig=startInkProfApp(projectFolder)
%STARTINKPROFAPP Set up InkProf and open the project workflow app.
arguments
 projectFolder (1,1) string = ""
end
setupInkProf();
fig=inkprof.app(projectFolder);
end
