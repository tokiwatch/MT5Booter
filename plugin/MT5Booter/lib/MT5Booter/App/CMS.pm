package MT5Booter::App::CMS;
use strict;
use base qw( MT::App );
use MT::Util qw( remove_html dirify encode_html );
sub plugin {
    return MT->component('MT5Booter');
}
sub _log {
    my ($msg) = @_;
    return unless defined($msg);
    my $prefix = sprintf "%s:%s:%s: %s", caller();
    $msg = $prefix . $msg if $prefix;
    use MT::Log;
    my $log = MT::Log->new;
    $log->message($msg) ;
    $log->save or die $log->errstr;
    return;
}
sub show_dialog {
    my $app = shift;
#init($app);
    my $tmpl = $app->load_tmpl('booter.tmpl');
    my $params;
#set defaults if they aren't defined
    $params->{'NumberEntries'} = "10";
    $params->{'NumberPages'}   = "0";
    $params->{'RateEntries'}   = "1";
    $params->{'AddComments'}   = "1";
    return $app->build_page($tmpl, $params);
}
sub menu_create_entries {
    my $app = shift;
    my $plugin = plugin;
    my $config = $plugin->get_config_hash();
#get parameters from settings
    my $NumberYears   = int($config->{NumberYears});
    my $NumberTags    = int($config->{NumberTags});
    my $NumberEntries = $app->{query}->param('NumberEntries');
    my $RateEntries   = $app->{query}->param('RateEntries');
    my $RatingType    = $app->{query}->param('RatingType');
    my $AddComments   = $app->{query}->param('AddComments');
    my $AddCategories = $app->{query}->param('AddCategories');
    my $AddCFData     = $app->{query}->param('AddCFData');
    my $blog_id       = $app->{query}->param('blog_id');
    my $author_id     = $app->{query}->param('author_id');
#create the entries
    if ($NumberEntries) {
        create_entries($app, $blog_id, "Entry", $NumberEntries, $NumberYears, $NumberTags, $RateEntries, $RatingType, $AddComments, $AddCategories, $AddCFData);
    }
    my $tmpl = $plugin->load_tmpl('booter.tmpl');
    my $param;
    $param->{'success'}       = $NumberEntries . " entries created successfully! Rock on!";
    $param->{'NumberEntries'} = $NumberEntries;
    $param->{'NumberYears'}   = $NumberYears;
    $param->{'NumberTags'}    = $NumberTags;
#how to reload in modal dialog, though? hm, seems to work automatically
    return $app->build_page($tmpl, $param);
}
sub create_entries {
#how can this be adapted to also create Pages? is it just a flag of MT::Entries?
    my $app           = shift;
    my $blog_id       = shift;
    my $EntryType     = shift;
    my $NumberEntries = shift;
    my $NumberYears   = shift;
    my $NumberTags    = shift;
    my $RateEntries   = shift;
    my $RatingType    = shift;
    my $AddComments   = shift;
    my $AddCategories = shift;
    my $AddCFData     = shift;
    if ($EntryType eq "Entry") {
        use MT::Entry;
        $NumberEntries = $NumberEntries;
    } else {
        use MT::Page;
#fix me
# $NumberEntries = $Number;
    }
#actually create the entries
    for ( my $i = 0; $i < $NumberEntries; $i++) {
        my $entry;
        if ($EntryType eq "Entry") {
            $entry = MT::Entry->new;
        } else {
            $entry = MT::Page->new;
        }
        $entry->blog_id($blog_id);
        $entry->status(MT::Entry::RELEASE());
#let's randomize the author
        my $RandomUser = random_user();
        my $author_id = $RandomUser->id;
        $entry->author_id($author_id);
        if ($NumberTags) {
            my @tags = get_random_tags($NumberTags);
            $entry->tags(@tags);
        }
        my $random_date = random_date($NumberYears);
        $entry->authored_on($random_date);
#make sure entry can be commented on
        $entry->allow_comments(1);
        $entry->save or die $entry->errstr;
        my $entry_id = $entry->id;
#now assign entry rating, if user has specified that
        if ($RateEntries) {
            my $plugin = plugin;
#so all ratings will appear as if made by the logged in user? let's try randomizing that--not to mention the number of users who rated the entry
#maybe try randomizing number of times the entry has been rated, and accept that there will be some redundant ratings (which will go down as the number of authors increases)
            my $NumberTimesRated = random_number_times(10);
            for ( my $j = 0; $j < $NumberTimesRated; $j++) {
                my $RandomUser = random_user();
#randomize rating
                my $RandomRating = random_rating($RatingType);
                $entry->set_score($plugin->key, $RandomUser, $RandomRating, 1);
            }
        }
# add some comments if user has specified that
        if ($AddComments) {
            my $NumberComments = random_number_times(5);
            for ( my $k = 0; $k < $NumberComments; $k++) {
                my $RandomUser = random_user();
                my $comment_author_id = $RandomUser->id;
                my $author_display_name = $RandomUser->nickname;
#create random comment
                random_comment($blog_id, $entry_id, $comment_author_id, $author_display_name, "");
            }
        }
#add category to some entries, if AddCategories is set
        if ($AddCategories) {
            my $NumberCategories = random_number_times(3);
            for ( my $m = 0; $m < $NumberCategories; $m++) {
#add random number of categories--zero
                my $Category = random_category($blog_id);
                if ($Category) {
                    my $category_id = $Category->id;
#if $m is zero (first iteration) than that category is primary
                    my $is_primary = 0;
                    if ($m == 0) {
                        $is_primary = 1;
                    } else {
                        $is_primary = 0;
                    }
#then add it to the entry
                    add_category_to_entry($blog_id, $entry_id, $category_id, $is_primary);
                }
            }
        }
#add custom field data to entries, if AddCFData is set
#if ($AddCFData) {
    add_cf_data_to_entry($blog_id, $entry_id);
#}
    my $title = "";
    my $entry_body = "";
    require Acme::Wabby;
#Acme::Wabby::import(qw(:errors));
#get seed text from settings
    my $plugin = plugin;
    my $config = $plugin->get_config_hash();
    my $seedtext =  $config->{SeedText};
    my $wabby = Acme::Wabby->new(
            min_len             => 40, max_len                         => 200,
            punctuation         => [".","?","!","..."], case_sensitive => 0,
            hash_file           => "./wabbyhash.dat", list_file        => "./wabbylist.dat",
            autosave_on_destroy => 0, max_attempts                     => 1000 );
    $wabby->add($seedtext);
    $entry_body = $wabby->spew;
#$entry_body = "booter";
    $wabby = Acme::Wabby->new(
            min_len             => 2, max_len                          => 6,
            punctuation         => [".","?","!","..."], case_sensitive => 0,
            hash_file           => "./wabbyhash.dat", list_file        => "./wabbylist.dat",
            autosave_on_destroy => 0, max_attempts                     => 1000 );
    $wabby->add($seedtext);
    $title = $wabby->spew;
    $entry->title($title);
    $entry->text($entry_body);
    $entry->save or die $entry->errstr;
    }
    return 1;
}
#this is not finished yet, just barely begun
sub remove_entries {
    my @Entries = MT::Entry->load();
}

sub random_date {
    my $years = shift;
    my @date = localtime(time - int(rand($years * 365 * 24 * 60 * 60)));
    return sprintf("%04d%02d%02d%02d%02d%02d",
            $date[5] + 1900, $date[4] + 1, $date[3], $date[2], $date[1], $date[0]
            );
}
sub get_random_tags {
    my @tags;
    my $count = shift;
    my @word_pool = qw(
            booter biddle trizzle alcina morgana bubba fozboot cat cats kitties persephone aggamemnon cute lolcat ICANHAZ
            laddering adminisdribble ebrandgelist t-patcher flying-k bogof docu-soap mattressing crunch if-by-whiskey
            fast-on skip bolt-ons banked sleepwork snatiation drunkalog olf chessically heel kino epiphany-risk game
            step-on horseracism baghouse skeet prop sit-ski pink drawling hundo freeskier outboarding run-off crop
            interiorscaping chicken-winging munitionette lysdexia gigachurch monster glass omega-block bumping money-good
            );
    for (my $i = 0; $i < $count; $i++) {
        push @tags, $word_pool[rand(scalar @word_pool)];
    }
    return @tags;
}

sub random_rating {
    my $RatingType = shift;
    my $RandomRating = 0;
    if ($RatingType eq "binary") {
        my @ratings   = qw(0 100);
        $RandomRating = $ratings[rand(scalar @ratings)];
    } elsif ($RatingType eq "trinary") {
        my @ratings   = qw(0 50 100);
        $RandomRating = $ratings[rand(scalar @ratings)];
    } elsif ($RatingType eq "fivestar") {
        my @ratings   = qw(0 20 40 60 80 100);
        $RandomRating = $ratings[rand(scalar @ratings)];
    } elsif ($RatingType eq "onetoten") {
        my @ratings   = qw(0 10 20 30 40 50 60 70 80 90 100);
        $RandomRating = $ratings[rand(scalar @ratings)];
    } else {
        $RandomRating = rand(100);
        $RandomRating = int($RandomRating + .5);
    }
    return $RandomRating;
}

sub random_user {
#my $app = shift;
    use MT::Author;
#get all users in app
    my @Authors = MT::Author->load();
    my $User    = $Authors[rand(scalar @Authors)];
#return $app->user;
    return $User;
}
sub random_comment {
    use MT::Comment;
    my $blog_id             = shift;
    my $entry_id            = shift;
    my $author_id           = shift;
    my $author_display_name = shift;
    my $comment_parent_id   = shift;
    my @comment_texts       = ();
    my $comment             = MT::Comment->new;
    $comment->blog_id($blog_id);
    $comment->entry_id($entry_id);
#right now only creates comments by registered users, but should also create ones from anonymous users
    my $not_anon_comment = random_number_times(5);
    require Acme::Wabby;
    my $wabby = Acme::Wabby->new;
#get seed text from settings
    my $plugin   = plugin;
    my $config   = $plugin->get_config_hash();
    my $seedtext = $config->{SeedText};
    $wabby->add($seedtext);
    @comment_texts   = ($wabby->spew);
    my $comment_text = $comment_texts[rand(scalar @comment_texts)];
    if ($not_anon_comment != 1) {
        $comment->commenter_id($author_id);
        $comment->author($author_display_name);
    } else {
        $comment->author("Anon Imus");
    }
    $comment->text($comment_text);
    my $comment_visible = random_number_times(1);
    $comment->visible($comment_visible);
#since we don't do date-based display of comments, I think it's okay to have them all be at the same time (that also prevents comments from having created on dates that would be before the entry date, which would be weird
#my $comment_created_on = random_date(1);
#$comment->created_on($comment_created_on);
        if ($comment_parent_id) {
        $comment->parent_id($comment_parent_id);
        }
#then junk filter the comment
        use MT::JunkFilter;
        MT::JunkFilter->filter($comment);
        $comment->save or die $comment->errstr;
        my $comment_id      = $comment->id;
        my $comment_replies = random_number_times(1);
#some comments should have replies--but only published ones
        if ($comment_visible && $comment_replies) {
#get number of replies
        my $number_replies = random_number_times(5);
        for ( my $i = 0; $i < $number_replies; $i++) {
        my $RandomUser = random_user();
        my $comment_reply_author_id = $RandomUser->id;
        my $author_display_name = $RandomUser->nickname;
#create random comment
        random_comment($blog_id, $entry_id, $comment_reply_author_id, $author_display_name, $comment_id);
        }
        }
}
sub random_number_times {
    my $number_times_max = shift;
    my $NumberTimes      = rand($number_times_max);
    $NumberTimes         = int($NumberTimes + .5);
    return $NumberTimes;
}
sub random_top_level_category {
    my $blog_id = shift;
    use MT::Category;
    my @Categories = MT::Category->top_level_categories($blog_id);
    my $Category   = $Categories[rand(scalar @Categories)];
    return $Category;
}
sub random_category {
#pick random category from all belonging to that blog
    my $blog_id = shift;
    use MT::Category;
    my @Categories = MT::Category->load({ blog_id => $blog_id });
    my $Category   = $Categories[rand(scalar @Categories)];
    return $Category;
}
sub random_subcategory {
    my $category_id = shift;
    if (!$category_id) {
        die("Doh--no category_id in random_category");
    }
    use MT::Category;
    my $Category = MT::Category->load($category_id);
#get all sub-categories of that category
    my @SubCategories = $Category->children_categories();
    my $SubCategory   = $SubCategories[rand(scalar @SubCategories)];
    return $SubCategory;
}
sub add_category_to_entry {
    my $blog_id     = shift;
    my $entry_id    = shift;
    my $category_id = shift;
    my $is_primary  = shift;
    use MT::Placement;
    my $place = MT::Placement->new;
    $place->entry_id($entry_id);
    $place->blog_id($blog_id);
    $place->category_id($category_id);
    $place->is_primary($is_primary);
    $place->save or die $place->errstr;
    return 1;
}
sub create_category {
    my $blog_id = shift;
    my $parent_cat_id = shift;
    my $cat = MT::Category->new;
    $cat->blog_id($blog_id);
    $cat->label('temp');
    $cat->save or die $cat->errstr;
    my $cat_id = $cat->id;
    if ($parent_cat_id) {
#make the category a sub-category
        my $parent_cat = MT::Category->load($parent_cat_id);
#$cat->parent_category($parent_cat);
        $cat->parent($parent_cat_id);
#determine if parent category is a sub-category
        if ($parent_cat->parent_category) {
            $cat->label("Sub-sub-category $cat_id");
        } else {
            $cat->label("Sub-category $cat_id");
        }
    } else {
        $cat->label("Category $cat_id");
    }
    $cat->save or die $cat->errstr;
    return $cat_id;
}
sub create_demo {
    my $app = shift;
    my $plugin = plugin;
#determine what template sets are available
    my $sets = $app->registry("template_sets");
#iterate through the array and get the keys, and the label
#how do you iterate through an array in perl again?
#while( my ($k, $v) = each %$sets ) {
#  print "key: $k, value: $v.\n";
#}
#for my $set ($sets) {
# $template_set_name = $set[''];
#}
#create the demo blogs -- hard-coded and assuming MTCS is installed, which is very wrong indeed
    create_blog($app, "Classic Blog", "This is a classic Movable Type blog like the one in MT4.", "mt_blog", 1, 1);
    create_blog($app, "Community Blog", "This is a blog with community features like favorites and userpics.", 'mt_community_blog', 1, 1);
    create_blog($app, "Forums Blog", "This is a forums blog for discussing stuff.", 'mt_community_forum', 1, 1);
    my $tmpl = $plugin->load_tmpl('create_demo_confirm.tmpl');
    my $param;
    $param->{'CreateDemoSuccess'} = "Your demo blogs have been created successfully.";
    return $app->build_page($tmpl, $param);
}
sub create_blog {
    my $app               = shift;
    my $BlogName          = shift;
    my $BlogDescription   = shift;
    my $blog_template     = shift;
    my $create_entries    = shift;
    my $create_categories = shift;
    use MT::Blog;
    my $blog = new MT::Blog;
    $blog->name($BlogName);
    $blog->description($BlogDescription);
    $blog->save or die $blog->errstr;
    $blog->create_default_templates($blog_template);
    my $blog_id = $blog->id;
#need to set publishing paths in an intelligent way
#like getting the host of the machine
#then assume that blog will be published to blogs at html root
    my $DefaultSiteURL  = $app->config('DefaultSiteURL');
    my $DefaultSitePath = $app->config('DefaultSitePath');
    if (!$DefaultSiteURL)  { $DefaultSiteURL  = $app->base . "/blogs/" };
    if (!$DefaultSitePath) { $DefaultSitePath = "/blogs" };
    $blog->site_url( $DefaultSiteURL  . "/blog-" . $blog_id);
    $blog->site_path($DefaultSitePath . "/blog-" . $blog_id);
    $blog->save or die $blog->errstr;
#create categories for that blog
    if ($create_categories) { create_categories($blog_id); }
#create entries for that blog
    if ($create_entries) { create_entries($app, $blog_id, "Entry", 10, 1, 5, 0, 0, 1); }
    return $blog_id;
}
sub menu_create_categories {
    my $app     = shift;
    my $plugin  = plugin;
    my $blog_id = $app->{query}->param('blog_id');
#actaully create the categories
    create_categories($blog_id);
    my $tmpl = $plugin->load_tmpl('booter_confirm.tmpl');
    my $param;
    $param->{'confirm_message'} = "Your categories have been created successfully.";
    $param->{'confirm_link'}    = "Categories listing";
    $param->{'confirm_mode'}    = "list_cat";
    return $app->build_page($tmpl, $param);
}
sub create_categories {
    my $blog_id = shift;
#always create five top-level categories
    my $number_categories = 5;
    for (my $i = 0; $i < $number_categories; $i++) {
        my $cat_id = create_category($blog_id, "");
#create sub-categories for that category
        my $number_sub_categories = random_number_times(3);
        for (my $j = 0; $j < $number_sub_categories; $j++) {
            my $sub_cat_id = create_category($blog_id, $cat_id);
#create sub-sub-categories for that sub-category
            my $number_subsub_categories = random_number_times(2);
            for (my $k = 0; $k < $number_subsub_categories; $k++) {
                create_category($blog_id, $sub_cat_id);
            }
        }
    }
    return;
}
sub add_forums {
    my $blog_id  = shift;
    my $entry_id = shift;
#add just a single category for now - this code is tailored to the MTCS forums
    my $CategoryGroup = random_top_level_category($blog_id);
    if ($CategoryGroup) {
        my $category_group_id = $CategoryGroup->id;
#pick a random category within that category group
        my $Category = random_category($category_group_id);
        if ($Category) {
            my $category_id = $Category->id;
#then add it to the entry
            add_category_to_entry($blog_id, $entry_id, $category_id);
        }
    }
}
sub menu_create_users {
    my $app     = shift;
    my $plugin  = plugin;
    my $blog_id = $app->{query}->param('blog_id');
#actaully create the users--should allow user to say how many, which means displaying dialog - to do
    create_users(10);
    my $tmpl = $plugin->load_tmpl('booter_confirm.tmpl');
    my $param;
    $param->{'confirm_message'} = "Your users have been created successfully.";
    $param->{'confirm_link'}    = "Users listing";
    $param->{'confirm_mode'}    = "list_user";
    return $app->build_page($tmpl, $param);
}
sub create_users {
    my $NumberUsers = shift;
    my $blog_id     = shift;
    my @Users;
    my $count = 0;
#my @UsernamesUsed;
#get all roles in system
    use MT::Role;
    my @Roles = MT::Role->load();
    while ($NumberUsers != $count) {
        my $DisplayName = create_user_name();
#derive their nickname from their name
        my $username = createUsername($DisplayName);
#check to see if the username has been used, otherwise put it in the array of usernames that have been used
#if it's been used, what to do? skip this iteration of the while loop
#I think it's actually better to check for existence of user in MT, though that is more expensive, it is almost much safer, and means that users can be created
#in more than one batch
#if(!in_array_str($username, @UsernamesUsed)) {
    if (findAuthor($username)) {
#don't create this user
        next;
    }
    my $author = create_user($username, $DisplayName);
#set status--most should be enabled, but a few should be disabled or pending -- enabled is 1, disabled is 2, what is pending? 3?
    my $author_status = 0;
    my $author_status_chances = random_number_times(10);
    if ($author_status_chances == 1) {
        $author_status = 2;
    } elsif ($author_status_chances == 2) {
        $author_status = 3;
    } else {
        $author_status = 1;
    }
    $author->status($author_status);
    $author->save
        or die $author->errstr;
#if users are being created for blog, then assign them random role on that blog
    if (!$blog_id) {
#get all blogs in system
        use MT::Blog;
        my @Blogs = MT::Blog->load();
#assign the user a  on a blog or blogs--some should be sysadmins, but some not
#for now, just assign them a role on one blog, unless they're a sysadmin
        my $author_sysadmin = random_number_times(10);
        if ($author_sysadmin == 1) { $author->is_superuser(1);
        } elsif ($author_sysadmin == 2) { $author->can_create_blog(1);
        } elsif ($author_sysadmin == 3) { $author->can_view_log(1);
        } elsif ($author_sysadmin == 4) { $author->can_manage_plugins(1);
        } elsif ($author_sysadmin == 5) { $author->can_edit_templates(1);
        } else {
#give them a random role on a random blog, but no system-level privileges
#pick random blog
            my $blog = $Blogs[rand(scalar @Blogs)];
#pick random role
            my $role = $Roles[rand(scalar @Roles)];
#create the association
            use MT::Association;
#define a User - Role - Blog relationship --user has to exist, though, for this to be done
            MT::Association->link( $author => $role => $blog );
        }
#save the user again which is slightly inefficient
        $author->save or die $author->errstr;
    } else {
#load up the blog object from blog id
        my $blog = MT::Blog->load($blog_id);
#pick a random role
        my $role = $Roles[rand(scalar @Roles)];
#create the association for that blog with the random role
        MT::Association->link( $author => $role => $blog );
    }
#add one to count of users that were created
    $count++;
}
}
sub create_user {
    my $username    = shift;
    my $DisplayName = shift;
#derive the email from username
#this is another thing that could be user preference--what domain to use with email addresses
    my $email = $username . '@fozboot.com';
#then actually create the user
    use MT::Author;
    my $author = MT::Author->new;
    $author->name($username);
    $author->nickname($DisplayName);
    $author->email($email);
    $author->set_password('booter27');
    $author->save
        or die $author->errstr;
    return $author;
}
sub createUsername {
    my $DisplayName = shift;
#split the name in two
    my @name_elements = split(/ /, $DisplayName);
    my $first_initial = lc(substr($name_elements[0], 0, 1));
    my $lc_last_name = lc($name_elements[1]);
    my $username = $first_initial . $lc_last_name;
    return $username;
}
sub create_user_name {
    my $FirstName = getFirstName();
    my $LastName = getLastName();
    return "$FirstName $LastName";
}
sub getFirstName {
#probably should allow people to define their own name pools
    my @first_name_pool = qw(
            Chris Brad Nick Mark David Michael Peter Jenny Sarah Lisa Tania Penelope Jim Homer Marge Bart Maggie Montgomery Nelson
            Milhouse Ned Todd Rod Ralph Lindsay Clancy Dale Jessica Helen Tim Matt Jacqueline Patty Selma Abe Kent Barry Charles Kevin
            Maude Parker Miranda Samantha Roxy Amy Steven Melody);
    my $FirstName = $first_name_pool[rand(scalar @first_name_pool)];
    return $FirstName;
}
sub getLastName {
    my @last_name_pool = qw(
            Smith Davis Roberts Hall Nielson Young Lee Frampton Burns Simpson Flanders Wiggum Nagel Weir Garcia Cooper Gross Zachary
            Page Murphy Bouvier Brockman Bonds Hart Nelson);
    my $LastName = $last_name_pool[rand(scalar @last_name_pool)];
    return $LastName;
}
sub findAuthor() {
    my $username = shift;
#try to load author with that nickname
    use MT::Author;
    my $author = MT::Author->load({ name => $username });
    if ($author) {
        return 1;
    } else {
        return 0;
    }
}
sub menu_create_test_blog {
    my $app    = shift;
    my $plugin = plugin;
#create the blog
    my $blog_id = create_blog($app, "Test Blog", "This is a test blog pre-populated with users, categories, tags, entries and comments.", "mt_blog", 0, 0);
#create some categories for the blog
    create_categories($blog_id);
#create entries and comments for the blog
    create_entries($app, $blog_id, "Entry", 10, 5, 10, 0, 0, 1, 1);
#create a set of users for that blog
    create_user_set_for_blog($blog_id);
    my $tmpl = $plugin->load_tmpl('booter_confirm.tmpl');
    my $param;
    $param->{'confirm_message'} = "Your test blog has been created successfully.";
    $param->{'confirm_link'}    = "Blog dashboard";
    $param->{'confirm_mode'}    = "dashboard";
    $param->{'blog_id'}         = $blog_id;
    return $app->build_page($tmpl, $param);
}
sub menu_create_user_set {
    my $app     = shift;
    my $plugin  = plugin;
    my $blog_id = $app->{query}->param('blog_id');
    create_user_set_for_blog($blog_id);
    my $tmpl = $plugin->load_tmpl('booter_confirm.tmpl');
    my $param;
    $param->{'confirm_message'} = "Your user set for this blog has been created.";
    $param->{'confirm_link'}    = "Manage users";
    $param->{'confirm_mode'}    = "list_member";
    $param->{'blog_id'}         = $blog_id;
    return $app->build_page($tmpl, $param);
}
sub create_user_set_for_blog {
    my $blog_id = shift;
#load up the blog
    use MT::Blog;
    my $blog = MT::Blog->load($blog_id);
#get all roles in the system
    use MT::Role;
    my @Roles = MT::Role->load();
#iterate through the roles and create a user for each
    foreach my $role (@Roles) {
        my $role_name = $role->name;
        my $username  = lc($role_name);
        $username =~ s/ //;
#get random first name
        my $FirstName = getFirstName();
#create user
        my $author = create_user($username, "$FirstName $role_name");
#create association
        MT::Association->link( $author => $role => $blog );
    }
}
sub menu_create_custom_fields {
    my $app     = shift;
    my $plugin  = plugin;
    my $blog_id = $app->{query}->param('blog_id');
    create_custom_fields_for_blog($app);
    my $tmpl = $plugin->load_tmpl('booter_confirm.tmpl');
    my $param;
    $param->{'confirm_message'} = "Custom Fields for this blog have been created.";
    $param->{'confirm_link'}    = "Custom Fields";
    $param->{'confirm_mode'}    = "list_field";
    $param->{'blog_id'}         = $blog_id;
    return $app->build_page($tmpl, $param);
}
sub create_custom_fields_for_blog {
    my $app = shift;
    my $blog_id = $app->{query}->param('blog_id');
    use CustomFields::Field;
#for each object in the system, create all possible blog-level custom fields for that object--first, for entries
#get all object types supported in blog context
    my $customfield_objs = $app->registry('customfield_objects');
#get all custom field types
    my $customfield_types = $app->registry('customfield_types');
    foreach my $key (keys %$customfield_objs) {
        my $context = $customfield_objs->{$key}->{context};
        next if $context eq "system";
        $context = "blog" if $context eq "all";
#create custom fields of all types for that object
        foreach my $type_key (keys %$customfield_types) {
            create_custom_field($blog_id, $key, $type_key, $context);
        }
    }
}
sub create_custom_field {
    my $blog_id    = shift;
    my $obj_type   = shift;
    my $field_type = shift;
    my $context    = shift;
    #$field_type =~ s/./ /;
    my $field_name = ucfirst($context) . ucfirst($obj_type) . ucfirst($field_type) . "Field";
    my $field      = CustomFields::Field->new;
    $field->blog_id($blog_id);
    $field->name($field_name);
    $field->description("This field was created by MT5Booter.");
    $field->obj_type($obj_type);
    $field->type($field_type);
    $field->required(0);
    $field->tag("booter");
#if radio buttons or drop down, need to populate field options
    if (($field_type == "select") || ($field_type == "radio")) {
        $field->options("booter, biddle, trizzle");
    }
    $field->save or die $field->errstr;
# Dirify to tag name
    my $tag = MT::Util::dirify($field->name);
    $field->tag($tag);
    $field->save or die $field->errstr;
}
sub add_cf_data_to_entry {
    my $blog_id  = shift;
    my $entry_id = shift;
    use MT::Entry;
    my $entry = MT::Entry->load($entry_id);
#get all entry custom fields
    use CustomFields::Field;
    my %terms;
    $terms{blog_id}  = $blog_id;
    $terms{obj_type} = "entry";
    my @Fields = CustomFields::Field->load(\%terms);
#iterate through them and add data for all field types that can easily have data added to them programatically
    foreach my $Field (@Fields) {
        my $field_type     = $Field->type;
        my $field_basename = $Field->basename;
        if ($field_type eq "text") {
#generate some random text and put in that CF for that entry
            my $text = "booter biddle";
            my $meta;
            $meta->{$field_basename} = $text;
            use CustomFields::Util;
            my $result = CustomFields::Util::save_meta($entry, $meta);
        }
    }
}
sub menu_manage_template_mappings {
    my $app          = shift;
    my $plugin       = plugin;
    my $blog_id      = $app->{query}->param('blog_id');
    my $mapping_list = make_mapping_list($blog_id);
    my $tmpl         = $plugin->load_tmpl('list_template_mappings.tmpl');
    my $param;
#http://localhost/mt-test/MT-4.1-en/mt.cgi?__mode=list&_type=template&blog_id=1
    $param->{'status_message'} = "Here are your blog's template mappings.";
    $param->{'mapping_list'}   = $mapping_list;
    $param->{'confirm_link'}   = "Templates";
    $param->{'confirm_mode'}   = "list_template";
    $param->{'blog_id'}        = $blog_id;
    return $app->build_page($tmpl, $param);
}
sub make_mapping_list {
    my $blog_id = shift;
    use MT::TemplateMap;
    my $html = "<table width=\"400\" class=\"entry-listing-table compact\" cellpadding=\"10\" cellspacing=\"10\">";
    $html .= "<td><b>Archive Type</b></td>";
    $html .= "<td><b>File Template</b></td>";
    $html .= "<td><b>Preferred?</b></td>";
    $html .= "<td>&nbsp;</td>";
    my @TemplateMaps = MT::TemplateMap->load({ blog_id => $blog_id });
    foreach my $TemplateMap (@TemplateMaps) {
        $html .= "<tr class=\"odd\">";
        my $archive_type  = $TemplateMap->archive_type;
        my $template_id   = $TemplateMap->template_id;
        my $file_template = $TemplateMap->file_template;
        my $is_preferred  = $TemplateMap->is_preferred;
        $file_template    = "Default" if $file_template eq '';
        my $edit_link     = "<a href=\"mt.cgi?__mode=view&_type=template&id=$template_id&blog_id=$blog_id\" target=\"_top\">Edit</a>";
##$file_template = html_entities($file_template);
#require CGI;
#my $file_template_esc = CGI::html_entities( $file_template );
        $html .= "<td>$archive_type</td>";
        $html .= "<td>$file_template</td>";
        $html .= "<td>$is_preferred</td>";
        $html .= "<td>$edit_link</td>";
        $html .= "</tr>";
    }
    $html .= "</table>";
    return $html;
}
1;
