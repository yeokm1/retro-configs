# make the makefile.

BEGIN {
	driver_last = 0;
	drivers[0] = "drivers:"
}

/^# End drivers$/   { driver_section = 0 }

driver_section {
	split($1, a, ":");
	drivers[driver_last] = drivers[driver_last] " " a[1]
	if (length(drivers[driver_last]) > 50) {
		drivers[driver_last] = drivers[driver_last] " \\"
		driver_last++
	}
}

/^# Begin drivers$/ { driver_section = 1 }

/^drivers: / {
	while (getline && match($0, /^ /))
		;

	for (i = 0; i <= driver_last; i++)
		print drivers[i]
}

{ print }
