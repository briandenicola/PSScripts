param(
	[string] $Path
)

Configuration SystemSetup
{
	Environment SCRIPTS_HOME {
		Ensure = "Present"
		Name   = "SCRIPTS_HOME"
		Value  = $PATH
	}
}