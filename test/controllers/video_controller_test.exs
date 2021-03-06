defmodule Rumbl.VideoControllerTest do
  use Rumbl.ConnCase
  alias Rumbl.Video

  @valid_attrs %{url: "http://youtu.be", title: "Vid", description: "A Vid"}
  @invalid_attrs %{title: "invalid"}

  defp video_count(query), do: Repo.one(from v in query, select: count(v.id))

  setup %{conn: conn} = config do
    if config[:login_user] do
      user = insert_user(username: "dog")
      conn = assign(conn, :current_user, user)
      {:ok, conn: conn, user: user}
    else
      :ok
    end
  end

  test "requires user authentication on all actions", %{conn: conn} do
    Enum.each([
      get(conn, video_path(conn, :index)),
      get(conn, video_path(conn, :new)),
      post(conn, video_path(conn, :create, %{})),
      get(conn, video_path(conn, :show, "123")),
      get(conn, video_path(conn, :edit, "123")),
      put(conn, video_path(conn, :update, "123")),
      delete(conn, video_path(conn, :delete, "123")),
    ], fn conn ->
      assert html_response(conn, 302)
      assert conn.halted
    end)
  end

  test "authorizes actions against access by other users", %{conn: conn} do
    owner = insert_user(username: "owner")
    video = insert_video(owner, @valid_attrs)
    non_owner = insert_user(username: "sneaky")
    conn = assign(conn, :current_user, non_owner)

    assert_error_sent(:not_found, fn ->
      get(conn, video_path(conn, :show, video))
    end)
    assert_error_sent(:not_found, fn ->
      get(conn, video_path(conn, :edit, video))
    end)
    assert_error_sent(:not_found, fn ->
      put(conn, video_path(conn, :update, video, video: @valid_attrs))
    end)
    assert_error_sent(:not_found, fn ->
      delete(conn, video_path(conn, :delete, video))
    end)
  end

  @tag :login_user
  test "lists all user's videos on index", %{conn: conn, user: user} do
    other_user = insert_user(username: "other")
    user_video = insert_video(user, %{title: "Owned by user"})
    other_video = insert_video(other_user, %{title: "different video"})

    conn = get(conn, video_path(conn, :index))

    assert html_response(conn, 200) =~ ~r/Listing videos/
    assert String.contains?(conn.resp_body, user_video.title)
    refute String.contains?(conn.resp_body, other_video.title)
  end

  @tag :login_user
  test "creates a user video and redirects", %{conn: conn, user: user} do
    conn = post(conn, video_path(conn, :create), video: @valid_attrs)

    assert redirected_to(conn) == video_path(conn, :index)
    assert Repo.get_by!(Video, @valid_attrs).user_id == user.id
  end

  @tag :login_user
  test "does not create video and renders errors when invalid", %{conn: conn} do
    count_before = video_count(Video)
    conn = post(conn, video_path(conn, :create), video: @invalid_attrs)

    assert html_response(conn, 200) =~ "check the errors"
    assert count_before == video_count(Video)
  end
end
