<?php
$api = "http://192.168.1.11:5000/register";

$ch = curl_init($api);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

$data = [
    "image" => new CURLFile($_FILES["image"]["tmp_name"])
];

curl_setopt($ch, CURLOPT_POSTFIELDS, $data);

$response = curl_exec($ch);
curl_close($ch);

$result = json_decode($response, true);

if (isset($result["status"]) && $result["status"] === "success") {

    $vector = $result["face_vector"];
    $jsonVector = json_encode($vector);
    $sizeKB = round(strlen($jsonVector) / 1024, 2);

    echo "<h3>✅ Register Berhasil</h3>";
    echo "<p><b>Jumlah data:</b> ".count($vector)." nilai</p>";
    echo "<p><b>Ukuran:</b> {$sizeKB} KB</p>";

    echo "<textarea rows='15' cols='120' readonly>";
    echo htmlspecialchars($jsonVector);
    echo "</textarea>";

} else {
    echo "<h3>❌ Gagal</h3>";
    echo "<p>".($result["msg"] ?? "Respon tidak valid")."</p>";
}

echo "<br><br><a href='index.html'>⬅ Kembali</a>";

