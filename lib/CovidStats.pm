package CovidStats;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
    my $self = shift;
    
    ## Plugins
    $self->plugin('CovidStats::Plugin::InfluxDb');
    $self->plugin('CovidStats::Plugin::Api');
    
    ## Read config
    my $config = $self->plugin('Config', {file => 'conf/CovidStats.conf'});
    my $secret = $self->plugin('Config', {file => 'conf/CovidStatsSecret.conf'});
}


1;
