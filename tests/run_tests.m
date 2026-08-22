function results = run_tests()
%RUN_TESTS Run all unit tests for tools/.
tools_dir = fileparts(fileparts(mfilename('fullpath')));
addpath(tools_dir);
setup_paths();

suite = matlab.unittest.TestSuite.fromFolder(fileparts(mfilename('fullpath')));
results = run(suite);

table(results)
end
