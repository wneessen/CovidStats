package Mojolicious::Command::run;
use Mojo::Base 'Mojolicious::Command';
use Mojo::Base 'Mojolicious';
use Mojo::Util 'getopt';
use v5.014;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);
our $VERSION = '0.01';

has description => 'Import CoVID-19 data into InfluxDB';
has usage => sub { shift->extract_usage };

## The main method // run() {{{
sub run {
	my ($self, @cmdArgs) = @_;
	getopt(
		\@cmdArgs,
		'n|dryrun'      => \my $dryRun,
		'h|help'        => \my $showHelp,
	);
	if(defined($showHelp)) { $self->help; exit 0; }

    ## Array to store different Influx data lines
    my @influxDataLines;

    ## Fetch state data
    foreach my $stateId (keys %{$self->app->config->{stateIds}}) {
        my $stateName = $self->app->config->{stateIds}->{$stateId};
        $self->app->log->debug('Fetching CoVID-19 data for state "' . $stateName . '"');
        my $stateData = $self->app->fetchState($stateId);
        my $stateHash = $stateData->{features}->[0]->{attributes};
        if(!defined($stateData)) {
            $self->app->log->error('No data returned while trying to fetch state data for ' . $stateName);
            next;
        }

        my $updateTime = $stateHash->{Aktualisierung};
        if(!defined($updateTime)) {
            $self->app->log->error('No latest update timestamp found. Skipping.');
            next;
        }
        $updateTime =~ s/^(\d{10}).*/$1/g;

        my @dataPoints;
        if(defined($stateHash->{Fallzahl})) {
            push(@dataPoints, 'infected=' . $stateHash->{Fallzahl});
        }
        if(defined($stateHash->{Death})) {
            push(@dataPoints, 'death=' . $stateHash->{Death});
        }
        if(defined($stateHash->{faelle_100000_EW})) {
            push(@dataPoints, 'cases_per_100000=' . $stateHash->{faelle_100000_EW});
        }
        
        my $influxLine = 'covid19,location=' . $stateName . ',domain=by_state,stateid=' . $stateId
            . ' ' . join(',', sort @dataPoints) . ' ' . $updateTime;
        push(@influxDataLines, $influxLine);
    }
    
    ## Write data to InfluxDB
    if(!defined($dryRun)) {
        my $writeData = $self->app->callInflux(join("\n", @influxDataLines));
        if(!defined($writeData)) {
            $self->app->log->error('Data not recorded in database due to an error');
        }
    }
}
# }}}

1;

=head1 SYNOPSIS
 
Usage: APPLICATION run [OPTIONS]
 
   Options:
     -h, --help		Show this help screen
 
=cut

# vim: set ts=4 sw=4 sts=4 noet ft=perl foldmethod=marker norl: