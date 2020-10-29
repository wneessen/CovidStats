package Mojolicious::Command::run;
use Mojo::Base 'Mojolicious::Command';
use Mojo::Base 'Mojolicious';
use Mojo::Util 'getopt';
use v5.014;
use Data::Dumper;
use DateTime;
use Scalar::Util qw(looks_like_number);
our $VERSION = '0.03';

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

        my $updateTime = $stateHash->{Aktualisierung} / 1000;
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
        if(defined($stateHash->{cases7_bl_per_100k})) {
            push(@dataPoints, 'cases7_bl_per_100k=' . $stateHash->{cases7_bl_per_100k});
        }
        
        my $influxLine = 'covid19,state=' . $stateName . ',domain=by_state,stateid=' . $stateId
            . ' ' . join(',', sort @dataPoints) . ' ' . $updateTime;
        push(@influxDataLines, $influxLine);
    }
    
    ## Fetch district data
    foreach my $districtId (keys %{$self->app->config->{districtIds}}) {
        my $districtName = $self->app->config->{districtIds}->{$districtId};
        my $districtNameNoSpace = $districtName;
        $districtNameNoSpace =~ s/\s/_/g;
        $self->app->log->debug('Fetching CoVID-19 data for district "' . $districtName . '"');
        my $districtData = $self->app->fetchDistrict($districtId);
        my $districtHash = $districtData->{features}->[0]->{attributes};
        if(!defined($districtData)) {
            $self->app->log->error('No data returned while trying to fetch district data for ' . $districtName);
            next;
        }

        my $updateDate = $districtHash->{last_update};
        my $dtObj;
        if($updateDate =~ /(\d{1,2})\.(\d{1,2})\.(\d{4}), (\d{2}):(\d{2}) Uhr/) {
            $dtObj = DateTime->new(
                year      => $3,
                month     => $2,
                day       => $1,
                hour      => $4,
                minute    => $5,
                second    => 0,
                time_zone => 'Europe/Berlin',
            );
        }
        $dtObj->set_time_zone('UTC');
        my $updateTime = $dtObj->epoch;
        my @dataPoints;
        if(defined($districtHash->{cases})) {
            push(@dataPoints, 'cases=' . $districtHash->{cases});
        }
        if(defined($districtHash->{deaths})) {
            push(@dataPoints, 'deaths=' . $districtHash->{deaths});
        }
        if(defined($districtHash->{cases7_per_100k})) {
            push(@dataPoints, 'cases7_per_100k=' . $districtHash->{cases7_per_100k});
        }
        
        my $influxLine = 'covid19,district=' . $districtNameNoSpace . ',domain=by_district,districtid=' . $districtId
            . ' ' . join(',', sort @dataPoints) . ' ' . $updateTime;
        push(@influxDataLines, $influxLine);
    }
    
    ## Fetch Intensivbetten data
    foreach my $intensivId (keys %{$self->app->config->{intensivIds}}) {
        my $districtName = $self->app->config->{intensivIds}->{$intensivId};
        my $districtNameNoSpace = $districtName;
        $districtNameNoSpace =~ s/\s/_/g;
        $self->app->log->debug('Fetching Intensivbettenauslastung data for district "' . $districtName . '"');
        my $districtData = $self->app->fetchIntensivbetten($districtId);
        my $districtHash = $districtData->{features}->[0]->{attributes};
        if(!defined($districtData)) {
            $self->app->log->error('No data returned while trying to fetch district data for ' . $districtName);
            next;
        }

        my $updateDate = $districtHash->{daten_stand};
        my $dtObj;
        if($updateDate =~ /(\d{1,2})\.(\d{1,2})\.(\d{4}), (\d{2}):(\d{2}) Uhr/) {
            $dtObj = DateTime->new(
                year      => $3,
                month     => $2,
                day       => $1,
                hour      => $4,
                minute    => $5,
                second    => 0,
                time_zone => 'Europe/Berlin',
            );
        }
        $dtObj->set_time_zone('UTC');
        my $updateTime = $dtObj->epoch;
        my @dataPoints;
        if(defined($districtHash->{anzahl_standorte})) {
            push(@dataPoints, 'anzahl_standorte=' . $districtHash->{anzahl_standorte});
        }
        if(defined($districtHash->{anzahl_meldebereiche})) {
            push(@dataPoints, 'anzahl_meldebereiche=' . $districtHash->{anzahl_meldebereiche});
        }
        if(defined($districtHash->{betten_frei})) {
            push(@dataPoints, 'betten_frei=' . $districtHash->{betten_frei});
        }
        if(defined($districtHash->{betten_belegt})) {
            push(@dataPoints, 'betten_belegt=' . $districtHash->{betten_belegt});
        }
        if(defined($districtHash->{betten_gesamt})) {
            push(@dataPoints, 'betten_gesamt=' . $districtHash->{betten_gesamt});
        }
        if(defined($districtHash->{faelle_covid_aktuell})) {
            push(@dataPoints, 'faelle_covid_aktuell=' . $districtHash->{faelle_covid_aktuell});
        }
        if(defined($districtHash->{faelle_covid_aktuell_beatmet})) {
            push(@dataPoints, 'faelle_covid_aktuell_beatmet=' . $districtHash->{faelle_covid_aktuell_beatmet});
        }
        
        my $influxLine = 'covid19,district=' . $districtNameNoSpace . ',domain=intensivbetten,districtid=' . $districtId
            . ' ' . join(',', sort @dataPoints) . ' ' . $updateTime;
        push(@influxDataLines, $influxLine);
    }
    
    ## Write data to InfluxDB
    if(!defined($dryRun)) {
        $self->app->log->debug('Sending collected data to InfluxDB');
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