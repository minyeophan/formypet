CREATE INDEX idx_posts_user_activity ON posts (user_id, created_at DESC, id DESC);
CREATE INDEX idx_likes_user_activity ON post_likes (user_id, created_at DESC, post_id DESC);
CREATE INDEX idx_comments_user_activity ON post_comments (user_id, deleted_at, post_id, created_at DESC, id DESC);
