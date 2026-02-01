<!DOCTYPE html>
<html>
<head>
    <title>Face Recognition Demo</title>
</head>
<body>

<h2>REGISTER WAJAH</h2>
<form action="register.php" method="post" enctype="multipart/form-data">
    <input type="file" name="image" accept="image/*" required>
    <br><br>
    <button type="submit">Register</button>
</form>

<hr>

<h2>MATCH WAJAH</h2>
<form action="match.php" method="post" enctype="multipart/form-data">
    <label>Foto Baru:</label><br>
    <input type="file" name="image" accept="image/*" required>
    <br><br>

    <label>Face Vector (hasil register):</label><br>
    <textarea name="face_vector" rows="6" cols="100" required></textarea>
    <br><br>

    <button type="submit">Match</button>
</form>

</body>
</html>
