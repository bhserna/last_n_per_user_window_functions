schema do
  create_table :users do |t|
    t.string :name
  end

  create_table :posts do |t|
    t.integer :user_id
    t.string :title
  end

  add_index :posts, :user_id
end

seeds do
  users = create_list(User, count: 10) do
    { name: FFaker::Name.name }
  end
  
  create_list_for_each_record(Post, records: users, count: 100) do |user|
    { user_id: user.id, title: FFaker::CheesyLingo.title }
  end
end

models do
  class User < ActiveRecord::Base
    has_many :posts
  end

  class Post < ActiveRecord::Base
    belongs_to :user
  end
end

example "SQL query" do
  sql = <<-SQL
    SELECT * FROM (
      SELECT posts.*, dense_rank() OVER (
        PARTITION BY posts.user_id
        ORDER BY posts.id DESC
      ) AS posts_rank
      FROM posts
    ) AS ranked_posts
    WHERE posts_rank <= 3
  SQL

  result = ActiveRecord::Base.connection.execute(sql)
  puts result.to_a.inspect
end

example "With a fixed n" do
  class Post < ActiveRecord::Base
    scope :last_n_per_user, -> {
      select_sql = <<-SQL
        posts.*, dense_rank() OVER (
          PARTITION BY posts.user_id
          ORDER BY posts.id DESC
        ) AS posts_rank
      SQL

      ranked_posts = select(select_sql)
      from(ranked_posts, "posts").where("posts_rank <= 3")
    }
  end

  posts = Post.last_n_per_user.preload(:user)
  pp posts.group_by(&:user).map { |user, posts| [user.name, posts.map(&:id)] }
end

example "With a variable n" do
  class Post < ActiveRecord::Base
    scope :last_n_per_user, ->(n) {
      select_sql = <<-SQL
        posts.*, dense_rank() OVER (
          PARTITION BY posts.user_id
          ORDER BY posts.id DESC
        ) AS posts_rank
      SQL

      ranked_posts = select(select_sql)
      from(ranked_posts, "posts").where("posts_rank <= ?", n)
    }
  end

  posts = Post.last_n_per_user(3).preload(:user)
  pp posts.group_by(&:user).map { |user, posts| [user.name, posts.map(&:id)] }
end

example "In a has many association" do
  class User < ActiveRecord::Base
    has_many :posts
    has_many :last_posts, -> { last_n_per_user(3) }, class_name: "Post"
  end

  class Post < ActiveRecord::Base
    scope :last_n_per_user, ->(n) {
      select_sql = <<-SQL
        posts.*, dense_rank() OVER (
          PARTITION BY posts.user_id
          ORDER BY posts.id DESC
        ) AS posts_rank
      SQL

      ranked_posts = select(select_sql)
      from(ranked_posts, "posts").where("posts_rank <= ?", n)
    }
  end

  users = User.preload(:last_posts).limit(5)
  pp users.map { |user| [user.name, user.last_posts.map(&:id)] }
end

# Setup
# -----
# -- create_table(:users)
#    -> 0.0286s
# -- create_table(:posts)
#    -> 0.0032s
# -- add_index(:posts, :user_id)
#    -> 0.0018s
# 
# 
# Example: SQL query
# ------------------
# D, [2022-08-17T22:19:03.349216 #47726] DEBUG -- :    (1.6ms)      SELECT posts.*
#     FROM (
#       SELECT posts.*, dense_rank() OVER (
#         PARTITION BY posts.user_id
#         ORDER BY posts.id DESC
#       ) AS posts_rank
#       FROM posts
#     ) posts
#     WHERE posts_rank <= 3
# 
# [{"id"=>100, "user_id"=>1, "title"=>"Grated Coulommiers", "posts_rank"=>1}, {"id"=>99, "user_id"=>1, "title"=>"Nutty Affineurs", "posts_rank"=>2}, {"id"=>98, "user_id"=>1, "title"=>"Melting Brie", "posts_rank"=>3}, {"id"=>200, "user_id"=>2, "title"=>"Smokey Gouda", "posts_rank"=>1}, {"id"=>199, "user_id"=>2, "title"=>"Sharp Coulommiers", "posts_rank"=>2}, {"id"=>198, "user_id"=>2, "title"=>"Soft Gouda", "posts_rank"=>3}, {"id"=>300, "user_id"=>3, "title"=>"Nutty Coulommiers", "posts_rank"=>1}, {"id"=>299, "user_id"=>3, "title"=>"Grated Sheep", "posts_rank"=>2}, {"id"=>298, "user_id"=>3, "title"=>"Melting Cows", "posts_rank"=>3}, {"id"=>400, "user_id"=>4, "title"=>"Fat Coulommiers", "posts_rank"=>1}, {"id"=>399, "user_id"=>4, "title"=>"Cheeky Affineurs", "posts_rank"=>2}, {"id"=>398, "user_id"=>4, "title"=>"Milky Coulommiers", "posts_rank"=>3}, {"id"=>500, "user_id"=>5, "title"=>"Soft Coulommiers", "posts_rank"=>1}, {"id"=>499, "user_id"=>5, "title"=>"Grated Brie", "posts_rank"=>2}, {"id"=>498, "user_id"=>5, "title"=>"Cheeky Coulommiers", "posts_rank"=>3}, {"id"=>600, "user_id"=>6, "title"=>"Melting Sheep", "posts_rank"=>1}, {"id"=>599, "user_id"=>6, "title"=>"Soft Goats", "posts_rank"=>2}, {"id"=>598, "user_id"=>6, "title"=>"Cheesed Coulommiers", "posts_rank"=>3}, {"id"=>700, "user_id"=>7, "title"=>"Grated Brie", "posts_rank"=>1}, {"id"=>699, "user_id"=>7, "title"=>"Sharp Gouda", "posts_rank"=>2}, {"id"=>698, "user_id"=>7, "title"=>"Sharp Brie", "posts_rank"=>3}, {"id"=>800, "user_id"=>8, "title"=>"Nutty Coulommiers", "posts_rank"=>1}, {"id"=>799, "user_id"=>8, "title"=>"Nutty Goats", "posts_rank"=>2}, {"id"=>798, "user_id"=>8, "title"=>"Fat Affineurs", "posts_rank"=>3}, {"id"=>900, "user_id"=>9, "title"=>"Soft Brie", "posts_rank"=>1}, {"id"=>899, "user_id"=>9, "title"=>"Cheeky Cows", "posts_rank"=>2}, {"id"=>898, "user_id"=>9, "title"=>"Smokey Alpine", "posts_rank"=>3}, {"id"=>1000, "user_id"=>10, "title"=>"Dutch Affineurs", "posts_rank"=>1}, {"id"=>999, "user_id"=>10, "title"=>"Soft Affineurs", "posts_rank"=>2}, {"id"=>998, "user_id"=>10, "title"=>"Fat Alpine", "posts_rank"=>3}]
# 
# 
# Example: With a fixed n
# -----------------------
# D, [2022-08-17T22:19:03.351282 #47726] DEBUG -- :   Post Load (1.0ms)  SELECT "posts".* FROM (SELECT         posts.*, dense_rank() OVER (
#           PARTITION BY posts.user_id
#           ORDER BY posts.id DESC
#         ) AS posts_rank
#  FROM "posts") posts WHERE (posts_rank <= 3)
# D, [2022-08-17T22:19:03.365536 #47726] DEBUG -- :   User Load (0.5ms)  SELECT "users".* FROM "users" WHERE "users"."id" IN ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)  [["id", 1], ["id", 2], ["id", 3], ["id", 4], ["id", 5], ["id", 6], ["id", 7], ["id", 8], ["id", 9], ["id", 10]]
# [["Vicenta Ernser", [100, 99, 98]],
#  ["Miguelina Runolfsdottir", [200, 199, 198]],
#  ["Eartha Crooks", [300, 299, 298]],
#  ["Margene Abshire", [400, 399, 398]],
#  ["Crystal Kiehn", [500, 499, 498]],
#  ["Fonda Little", [600, 599, 598]],
#  ["Tracey Hettinger", [700, 699, 698]],
#  ["Jennefer Rempel", [800, 799, 798]],
#  ["Lauretta Kshlerin", [900, 899, 898]],
#  ["Wiley Little", [1000, 999, 998]]]
# 
# 
# Example: With a variable n
# --------------------------
# D, [2022-08-17T22:19:03.377333 #47726] DEBUG -- :   Post Load (3.2ms)  SELECT "posts".* FROM (SELECT         posts.*, dense_rank() OVER (
#           PARTITION BY posts.user_id
#           ORDER BY posts.id DESC
#         ) AS posts_rank
#  FROM "posts") posts WHERE (posts_rank <= 3)
# D, [2022-08-17T22:19:03.380736 #47726] DEBUG -- :   User Load (2.0ms)  SELECT "users".* FROM "users" WHERE "users"."id" IN ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)  [["id", 1], ["id", 2], ["id", 3], ["id", 4], ["id", 5], ["id", 6], ["id", 7], ["id", 8], ["id", 9], ["id", 10]]
# [["Vicenta Ernser", [100, 99, 98]],
#  ["Miguelina Runolfsdottir", [200, 199, 198]],
#  ["Eartha Crooks", [300, 299, 298]],
#  ["Margene Abshire", [400, 399, 398]],
#  ["Crystal Kiehn", [500, 499, 498]],
#  ["Fonda Little", [600, 599, 598]],
#  ["Tracey Hettinger", [700, 699, 698]],
#  ["Jennefer Rempel", [800, 799, 798]],
#  ["Lauretta Kshlerin", [900, 899, 898]],
#  ["Wiley Little", [1000, 999, 998]]]
# 
# 
# Example: In a has many association
# ----------------------------------
# D, [2022-08-17T22:19:03.391141 #47726] DEBUG -- :   User Load (0.3ms)  SELECT "users".* FROM "users" LIMIT $1  [["LIMIT", 5]]
# D, [2022-08-17T22:19:03.408675 #47726] DEBUG -- :   Post Load (6.8ms)  SELECT "posts".* FROM (SELECT         posts.*, dense_rank() OVER (
#           PARTITION BY posts.user_id
#           ORDER BY posts.id DESC
#         ) AS posts_rank
#  FROM "posts") posts WHERE (posts_rank <= 3) AND "posts"."user_id" IN ($1, $2, $3, $4, $5)  [["user_id", 1], ["user_id", 2], ["user_id", 3], ["user_id", 4], ["user_id", 5]]
# [["Vicenta Ernser", [100, 99, 98]],
#  ["Miguelina Runolfsdottir", [200, 199, 198]],
#  ["Eartha Crooks", [300, 299, 298]],
#  ["Margene Abshire", [400, 399, 398]],
#  ["Crystal Kiehn", [500, 499, 498]]]