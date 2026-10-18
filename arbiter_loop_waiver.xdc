# allows looping in the arbiters
set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets -of_objects \
    [get_cells -hier -filter {NAME =~ *arbiters*inferred*}]]