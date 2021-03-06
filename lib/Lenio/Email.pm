=pod
Lenio - Web-based Facilities Management Software
Copyright (C) 2013 A Beverley

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
=cut

package Lenio::Email;

use Dancer2 ':script';
use Dancer2::Plugin::Emailesque;
use Dancer2::Plugin::DBIC qw(schema resultset rset);
schema->storage->debug(1);
use Text::Autoformat qw(autoformat break_wrap);

sub send($)
{   my ($class, $args) = @_;

    my $login = $args->{login} or return;
    my $site_id = $args->{site_id} or return;
    $args->{siteurl} = config->{siteurl};

    my $template = Template->new
       ({INCLUDE_PATH => config->{lenio}->{emailtemplate}});

    my $site = Lenio::Site->site($site_id);
    my $org  = sprintf("%s (%s)", $site->org->name, $site->name);
    $args->{org} = $org;

    my $message;
    $template->process("$args->{template}.tt", $args, \$message)
	or error "Template process failed: " . $template->error();
    $message = autoformat $message, {all => 1, break=>break_wrap};

    if ($login->{is_admin})
    {
        my @users = rset('Login')->search(
             { 'sites.id' => $site_id },
             { join    => {'login_orgs' => {'org' => 'sites' }}}
        );
        foreach my $user (@users)
        {
            if ($user->email_comment && $args->{template} eq 'ticket/comment'
                || $user->email_ticket && $args->{template} eq 'ticket/new'
                || $user->email_ticket && $args->{template} eq ' ticket/update'
            ) {
                email {
                    to      => $user->email,
                    subject => $args->{subject}.$org,
                    message => $message,
                }
            }
        }
    }
    else
    {
        foreach my $admin (rset('Login')->search({ is_admin => 1 }))
        {
            email {
                to      => $admin->email,
                subject => $args->{subject}.$org,
                message => $message
            };
        }
    }
}

1;
